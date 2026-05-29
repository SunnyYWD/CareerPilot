"""Unit tests for the pure scoring helpers in matching_service.

Run from the SmartHire_AI directory:  pytest
"""
import pytest

from app.services.matching_service import (
    normalize_skill,
    skills_match,
    calculate_skill_match,
    calculate_education_match,
    _HAS_RAPIDFUZZ,
)


class TestNormalizeSkill:
    def test_lowercases_and_strips_separators(self):
        assert normalize_skill("Node.js") == "nodejs"
        assert normalize_skill("Postgre SQL") == "postgresql"
        assert normalize_skill("  React  ") == "react"

    def test_keeps_plus_and_hash(self):
        # C++ and C# must stay distinguishable.
        assert normalize_skill("C++") != normalize_skill("C#")

    def test_empty(self):
        assert normalize_skill("") == ""
        assert normalize_skill(None) == ""


class TestSkillsMatch:
    def test_exact_after_normalization(self):
        assert skills_match("Python", "python") is True
        assert skills_match("Node.js", "nodejs") is True

    def test_clearly_different(self):
        assert skills_match("React", "Vue") is False

    def test_empty_never_matches(self):
        assert skills_match("", "Python") is False
        assert skills_match("Python", "") is False

    def test_spelling_variant(self):
        # Resolved by the fuzzy pass when rapidfuzz is installed, and by the
        # substring fallback otherwise — either way these are the same skill.
        assert skills_match("PostgreSQL", "Postgres") is True

    def test_acronym_alias_needs_dictionary(self):
        # Fuzzy matching cannot resolve acronyms (no character overlap); this is
        # a known limitation that a curated alias table would address.
        if _HAS_RAPIDFUZZ:
            assert skills_match("JS", "JavaScript") is False


class TestCalculateSkillMatch:
    def test_full_match(self):
        seeker = [{"name": "Python"}, {"name": "PostgreSQL"}]
        jobs = ["python", "postgres"]
        assert calculate_skill_match(seeker, jobs) == 1.0

    def test_partial_match(self):
        seeker = [{"name": "Python"}]
        jobs = ["python", "java", "go"]
        assert calculate_skill_match(seeker, jobs) == pytest.approx(1 / 3)

    def test_no_job_skills_with_seeker_skills(self):
        assert calculate_skill_match([{"name": "Python"}], []) == 0.0

    def test_no_seeker_skills(self):
        assert calculate_skill_match([], ["python"]) == 0.0


class TestCalculateEducationMatch:
    def test_seeker_meets_requirement(self):
        # 本科 (2) for a job requiring 本科 (2)
        assert calculate_education_match("本科", 2) == 1.0

    def test_seeker_exceeds_requirement(self):
        assert calculate_education_match("硕士", 2) == 1.0

    def test_seeker_below_requirement(self):
        # 专科 (1) vs required 本科 (2) -> 1/2
        assert calculate_education_match("专科", 2) == pytest.approx(0.5)

    def test_no_requirement(self):
        assert calculate_education_match("本科", None) == 1.0

    def test_seeker_unknown(self):
        assert calculate_education_match(None, 2) == 0.0

    def test_string_requirement(self):
        assert calculate_education_match("本科", "本科") == 1.0
