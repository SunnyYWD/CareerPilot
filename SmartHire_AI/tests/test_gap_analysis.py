"""Unit tests for gap_analysis_service.

Assertions target the structural / numeric outputs (missing-skill lists, match
rate, qualification flags, level fields) which are independent of the i18n text
labels loaded from config. Run from the SmartHire_AI directory:  pytest
"""
from app.services.gap_analysis_service import (
    analyze_skill_gap,
    analyze_education_gap,
    analyze_experience_gap,
)


class TestAnalyzeSkillGap:
    def test_classifies_required_optional_and_matched(self):
        seeker = [{"name": "Python", "level": 3}]
        jobs = [
            {"name": "Python", "is_required": True},
            {"name": "Docker", "is_required": True},
            {"name": "Go", "is_required": False},
        ]
        result = analyze_skill_gap(seeker, jobs)

        assert result["required_missing"] == ["Docker"]
        assert result["optional_missing"] == ["Go"]
        assert [m["name"] for m in result["matched"]] == ["Python"]
        assert result["matched"][0]["your_level"] == 3
        # 1 of 2 required skills matched.
        assert result["match_rate"] == 0.5

    def test_full_match_rate_when_no_required(self):
        result = analyze_skill_gap([], [{"name": "Go", "is_required": False}])
        assert result["match_rate"] == 1.0
        assert result["optional_missing"] == ["Go"]

    def test_uses_fuzzy_matching(self):
        seeker = [{"name": "PostgreSQL", "level": 2}]
        jobs = [{"name": "Postgres", "is_required": True}]
        result = analyze_skill_gap(seeker, jobs)
        assert result["required_missing"] == []
        assert result["match_rate"] == 1.0


class TestAnalyzeEducationGap:
    def test_qualified_when_level_meets_requirement(self):
        result = analyze_education_gap(seeker_education=2, job_education_required=2)
        assert result["is_qualified"] is True
        assert result["your_level"] == 2
        assert result["required_level"] == 2

    def test_not_qualified_when_below(self):
        result = analyze_education_gap(seeker_education=1, job_education_required=3)
        assert result["is_qualified"] is False

    def test_no_requirement_is_qualified(self):
        result = analyze_education_gap(seeker_education=2, job_education_required=None)
        assert result["is_qualified"] is True
        assert result["required_level"] == -1


class TestAnalyzeExperienceGap:
    def test_no_requirement_is_qualified(self):
        result = analyze_experience_gap(work_experiences=[], experience_required=None)
        assert result["is_qualified"] is True
        assert result["gap_years"] == 0.0

    def test_unknown_level_not_qualified(self):
        result = analyze_experience_gap(work_experiences=[], experience_required=99)
        assert result["is_qualified"] is False
