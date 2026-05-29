import logging
import re
from typing import Dict, Any, List
from sqlalchemy.orm import Session
from app.services.db_service import (
    get_job_info,
    get_job_skills,
    get_seeker_info,
    get_seeker_education,
    get_seeker_skills,
    get_seeker_work_experience,
    get_seeker_project_experience,
)
from app.services.vector_service import (
    embed_text,
    calculate_cosine_similarity,
    build_seeker_text,
    build_job_text,
)
from app.services.vector_db_service import (
    get_match_score,
    batch_get_match_scores,
    store_match_score,
    check_and_update_if_needed,
)
from app.db.models import JobInfo, JobSeeker

logger = logging.getLogger(__name__)

try:
    from rapidfuzz.fuzz import token_set_ratio
    _HAS_RAPIDFUZZ = True
except ImportError:  # graceful fallback if rapidfuzz is not installed
    token_set_ratio = None
    _HAS_RAPIDFUZZ = False

# Fuzzy skill-name match threshold (token_set_ratio, 0-100).
FUZZY_MATCH_THRESHOLD = 85

# Single source of truth for education-level mapping (was duplicated inline below).
EDUCATION_LEVELS = {0: "高中及以下", 1: "专科", 2: "本科", 3: "硕士", 4: "博士"}
EDUCATION_NAME_TO_LEVEL = {name: level for level, name in EDUCATION_LEVELS.items()}


def normalize_skill(skill: str) -> str:
    """Lowercase and strip whitespace/separators so casing and punctuation
    variants (e.g. "Postgres" vs "PostgreSQL", "Node.js" vs "nodejs") compare
    cleanly before any fuzzy fallback. Keeps '+'/'#' so C++/C# stay distinct."""
    if not skill:
        return ""
    return re.sub(r"[\s._/\\-]+", "", skill.lower())


def skills_match(a: str, b: str) -> bool:
    """True if two skill names refer to the same skill: exact match after
    normalization, then a rapidfuzz token-set fallback (substring fallback when
    rapidfuzz is unavailable)."""
    na, nb = normalize_skill(a), normalize_skill(b)
    if not na or not nb:
        return False
    if na == nb:
        return True
    if _HAS_RAPIDFUZZ:
        return token_set_ratio(na, nb) >= FUZZY_MATCH_THRESHOLD
    return na in nb or nb in na


def calculate_single_match_score(db: Session, user_id: int, job_id: int) -> int:
    logger.info(f"[MatchScore] calculate_single_match_score called: userId={user_id}, jobId={job_id}")
    
    job_info = get_job_info(db, job_id)
    if not job_info:
        raise ValueError(f"Job {job_id} not found")
    
    seeker_info = get_seeker_info(db, user_id)
    if not seeker_info:
        raise ValueError(f"Seeker for user {user_id} not found")
    
    job_seeker_id = seeker_info["id"]
    logger.info(f"[MatchScore] Retrieved jobSeekerId={job_seeker_id} for userId={user_id}")
    
    job_entity = db.query(JobInfo).filter(JobInfo.id == job_id).first()
    seeker_entity = db.query(JobSeeker).filter(JobSeeker.user_id == user_id).first()
    
    if not job_entity or not seeker_entity:
        raise ValueError("Entity not found")
    
    cached_score = get_match_score(user_id, job_id)
    
    if cached_score:
        needs_update = check_and_update_if_needed(
            user_id,
            job_id,
            seeker_entity.updated_at,
            job_entity.updated_at,
        )
        
        if not needs_update:
            logger.info(f"[MatchScore] Using cached match score: userId={user_id}, jobId={job_id}, score={cached_score['match_score']}")
            return cached_score["match_score"]
        else:
            logger.info(f"[MatchScore] Cache expired, recalculating: userId={user_id}, jobId={job_id}")
    
    job_skills = get_job_skills(db, job_id)
    seeker_education = get_seeker_education(db, job_seeker_id)
    seeker_skills = get_seeker_skills(db, job_seeker_id)
    seeker_work_experiences = get_seeker_work_experience(db, job_seeker_id)
    seeker_project_experiences = get_seeker_project_experience(db, job_seeker_id)
    
    major = seeker_education.get("major", "") if seeker_education else ""
    university = seeker_education.get("school_name", "") if seeker_education else ""
    
    seeker_text = build_seeker_text(
        major=major,
        university=university,
        skills=seeker_skills,
        work_experiences=seeker_work_experiences,
        project_experiences=seeker_project_experiences,
    )
    
    job_text = build_job_text(
        job_title=job_info["job_title"],
        description=job_info["description"],
        responsibilities=job_info["responsibilities"],
        requirements=job_info["requirements"],
        skills=job_skills,
    )
    
    seeker_embedding = embed_text(seeker_text)
    job_embedding = embed_text(job_text)
    
    similarity = calculate_cosine_similarity(seeker_embedding, job_embedding)
    match_score = int(round(similarity * 100))
    match_score = max(0, min(100, match_score))
    
    store_match_score(
        seeker_id=user_id,
        job_id=job_id,
        similarity_score=similarity,
        match_score=match_score,
        seeker_updated_at=seeker_entity.updated_at,
        job_updated_at=job_entity.updated_at,
        seeker_vector=seeker_embedding,
        job_vector=job_embedding,
    )
    
    logger.info(f"[MatchScore] Calculated and stored: userId={user_id}, jobId={job_id}, similarity={similarity:.4f}, matchScore={match_score}")
    
    return match_score


def calculate_batch_match_scores(
    seeker_profile: Dict[str, Any], jobs: List[Dict[str, Any]], user_id: int = None, db: Session = None
) -> List[Dict[str, Any]]:
    logger.info(f"[BatchMatch] calculate_batch_match_scores called: userId={user_id}, jobCount={len(jobs)}")
    
    if not user_id or not db:
        logger.warning(f"[BatchMatch] No userId or db provided, using fallback")
        return _calculate_batch_without_cache(seeker_profile, jobs)
    
    seeker_info = get_seeker_info(db, user_id)
    if not seeker_info:
        logger.warning(f"[BatchMatch] Seeker not found for user {user_id}, falling back to seeker_profile")
        return _calculate_batch_without_cache(seeker_profile, jobs, user_id, db)
    
    job_seeker_id = seeker_info["id"]
    logger.info(f"[BatchMatch] Retrieved jobSeekerId={job_seeker_id} for userId={user_id}")
    
    seeker_skills = get_seeker_skills(db, job_seeker_id)
    seeker_education = get_seeker_education(db, job_seeker_id)
    
    seeker_edu_str = None
    if seeker_education:
        seeker_edu_level = seeker_education.get("education")
        if seeker_edu_level is not None:
            seeker_edu_str = EDUCATION_LEVELS.get(seeker_edu_level, "")
    
    results = []
    for job in jobs:
        job_id = job.get("jobId")
        logger.info(f"[BatchMatch] Processing jobId={job_id} for userId={user_id}")
        try:
            match_score = calculate_single_match_score(db, user_id, job_id)
            logger.info(f"[BatchMatch] Got matchScore={match_score} for jobId={job_id}")
            
            job_skills = get_job_skills(db, job_id)
            job_info = get_job_info(db, job_id)
            if not job_info:
                continue
            
            skill_match = calculate_skill_match(seeker_skills, job_skills)
            
            education_match = calculate_education_match(
                seeker_edu_str,
                job_info.get("education_required")
            )
            
            cached_score = get_match_score(user_id, job_id)
            similarity = cached_score["similarity_score"] if cached_score else 0.0
            
            results.append({
                "jobId": job_id,
                "matchScore": match_score,
                "similarity": round(similarity, 4),
                "details": {
                    "skillMatch": round(skill_match, 4),
                    "descriptionMatch": round(similarity, 4),
                    "educationMatch": education_match,
                }
            })
        except Exception as e:
            logger.warning(f"Failed to calculate match score for job {job_id}: {e}")
            continue
    
    return results


def _calculate_batch_without_cache(
    seeker_profile: Dict[str, Any],
    jobs: List[Dict[str, Any]],
    user_id: int = None,
    db: Session = None,
) -> List[Dict[str, Any]]:
    if user_id and db:
        try:
            seeker_info = get_seeker_info(db, user_id)
            if seeker_info:
                job_seeker_id = seeker_info["id"]
                seeker_education = get_seeker_education(db, job_seeker_id)
                seeker_skills = get_seeker_skills(db, job_seeker_id)
                seeker_work_experiences = get_seeker_work_experience(db, job_seeker_id)
                seeker_project_experiences = get_seeker_project_experience(db, job_seeker_id)
                
                major = seeker_education.get("major", "") if seeker_education else ""
                university = seeker_education.get("school_name", "") if seeker_education else ""
                
                seeker_text = build_seeker_text(
                    major=major,
                    university=university,
                    skills=seeker_skills,
                    work_experiences=seeker_work_experiences,
                    project_experiences=seeker_project_experiences,
                )
                seeker_embedding = embed_text(seeker_text)
                
                seeker_entity = db.query(JobSeeker).filter(JobSeeker.user_id == user_id).first()
                
                results = []
                for job in jobs:
                    job_id = job.get("jobId")
                    job_info = get_job_info(db, job_id)
                    
                    if not job_info:
                        continue
                    
                    job_skills = get_job_skills(db, job_id)
                    job_text = build_job_text(
                        job_title=job_info["job_title"],
                        description=job_info["description"],
                        responsibilities=job_info["responsibilities"],
                        requirements=job_info["requirements"],
                        skills=job_skills,
                    )
                    job_embedding = embed_text(job_text)
                    overall_similarity = calculate_cosine_similarity(seeker_embedding, job_embedding)
                    
                    skill_match = calculate_skill_match(seeker_skills, job_skills)
                    
                    description_match = calculate_description_match(seeker_text, job_info["description"], seeker_embedding)
                    
                    seeker_edu_str = None
                    if seeker_education:
                        seeker_edu_level = seeker_education.get("education")
                        if seeker_edu_level is not None:
                            seeker_edu_str = EDUCATION_LEVELS.get(seeker_edu_level, "")
                    
                    education_match = calculate_education_match(
                        seeker_edu_str,
                        job_info.get("education_required")
                    )
                    
                    match_score = int(round(overall_similarity * 100))
                    match_score = max(0, min(100, match_score))
                    
                    job_entity = db.query(JobInfo).filter(JobInfo.id == job_id).first()
                    if job_entity and seeker_entity:
                        store_match_score(
                            seeker_id=user_id,
                            job_id=job_id,
                            similarity_score=overall_similarity,
                            match_score=match_score,
                            seeker_updated_at=seeker_entity.updated_at,
                            job_updated_at=job_entity.updated_at,
                            seeker_vector=seeker_embedding,
                            job_vector=job_embedding,
                        )
                    
                    results.append({
                        "jobId": job_id,
                        "matchScore": match_score,
                        "similarity": round(overall_similarity, 4),
                        "details": {
                            "skillMatch": round(skill_match, 4),
                            "descriptionMatch": round(description_match, 4),
                            "educationMatch": education_match,
                        }
                    })
                
                return results
        except Exception as e:
            logger.warning(f"[Matching] Failed to get data from database, falling back to seeker_profile: {e}")
    work_experiences = []
    for exp in seeker_profile.get("workExperiences", [])[:2]:
        work_experiences.append({
            "position": exp.get("position", ""),
            "description": exp.get("description", "")
        })
    
    project_experiences = []
    for proj in seeker_profile.get("projectExperiences", [])[:2]:
        project_experiences.append({
            "project_name": proj.get("projectName", ""),
            "description": proj.get("description", "")
        })
    
    seeker_text = build_seeker_text(
        major=seeker_profile.get("major", ""),
        university=seeker_profile.get("university", ""),
        skills=seeker_profile.get("skills", []),
        work_experiences=work_experiences,
        project_experiences=project_experiences,
    )
    seeker_embedding = embed_text(seeker_text)
    
    results = []
    
    for job in jobs:
        job_id = job.get("jobId")
        job_title = job.get("jobTitle", "")
        description = job.get("description", "")
        responsibilities = job.get("responsibilities", "")
        requirements = job.get("requirements", "")
        skills = job.get("skills", [])
        
        job_full_text = build_job_text(
            job_title=job_title,
            description=description,
            responsibilities=responsibilities,
            requirements=requirements,
            skills=skills,
        )
        job_embedding = embed_text(job_full_text)
        
        overall_similarity = calculate_cosine_similarity(seeker_embedding, job_embedding)
        
        skill_match = calculate_skill_match(
            seeker_profile.get("skills", []),
            skills
        )
        
        description_match = calculate_description_match(
            seeker_text,
            description,
            seeker_embedding,
        )
        
        education_match = calculate_education_match(
            seeker_profile.get("highestEducation"),
            job.get("educationRequired")
        )
        
        match_score = int(round(overall_similarity * 100))
        match_score = max(0, min(100, match_score))
        
        if user_id and db:
            job_entity = db.query(JobInfo).filter(JobInfo.id == job_id).first()
            seeker_entity = db.query(JobSeeker).filter(JobSeeker.user_id == user_id).first()
            
            if job_entity and seeker_entity:
                store_match_score(
                    seeker_id=user_id,
                    job_id=job_id,
                    similarity_score=overall_similarity,
                    match_score=match_score,
                    seeker_updated_at=seeker_entity.updated_at,
                    job_updated_at=job_entity.updated_at,
                    seeker_vector=seeker_embedding,
                    job_vector=job_embedding,
                )
        
        results.append({
            "jobId": job_id,
            "matchScore": match_score,
            "similarity": round(overall_similarity, 4),
            "details": {
                "skillMatch": round(skill_match, 4),
                "descriptionMatch": round(description_match, 4),
                "educationMatch": education_match,
            }
        })
    
    return results


def calculate_skill_match(seeker_skills: List[Dict], job_skills: List[str]) -> float:
    if not job_skills:
        return 1.0 if not seeker_skills else 0.0
    
    if not seeker_skills:
        return 0.0
    
    seeker_skill_names = [s.get("name", "") for s in seeker_skills if s.get("name")]
    job_skill_names = [s for s in job_skills if s]

    matched_count = 0
    for job_skill in job_skill_names:
        if any(skills_match(job_skill, seeker_skill)
               for seeker_skill in seeker_skill_names):
            matched_count += 1

    return matched_count / len(job_skill_names) if job_skill_names else 0.0


def calculate_description_match(
    seeker_text: str, job_description: str, seeker_embedding: List[float] = None
) -> float:
    if not job_description:
        return 1.0

    # Reuse the caller's already-computed seeker embedding when available to
    # avoid re-embedding the same seeker text on every job in a batch.
    if seeker_embedding is None:
        seeker_embedding = embed_text(seeker_text)
    job_desc_embedding = embed_text(job_description)

    return calculate_cosine_similarity(seeker_embedding, job_desc_embedding)


def calculate_education_match(seeker_education: str, job_education_required: Any) -> float:
    if job_education_required is None:
        return 1.0
    
    if seeker_education is None:
        return 0.0
    
    seeker_level = EDUCATION_NAME_TO_LEVEL.get(seeker_education, -1)

    if isinstance(job_education_required, int):
        job_level = job_education_required
    elif isinstance(job_education_required, str):
        job_level = EDUCATION_NAME_TO_LEVEL.get(job_education_required, -1)
    else:
        return 0.0
    
    if seeker_level == -1 or job_level == -1:
        return 0.0
    
    if seeker_level >= job_level:
        return 1.0
    else:
        return max(0.0, seeker_level / job_level if job_level > 0 else 0.0)
