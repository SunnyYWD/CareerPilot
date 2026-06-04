-- SmartHire backend database schema.
-- This script is derived from SmartHire_Backend entity classes, mapper XML files,
-- and annotation-based SQL. It is safe to run repeatedly.

CREATE DATABASE IF NOT EXISTS smarthire
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE smarthire;

CREATE TABLE IF NOT EXISTS `user` (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT 'User ID',
  username VARCHAR(64) NOT NULL COMMENT 'Username',
  password VARCHAR(255) NOT NULL COMMENT 'Encoded password',
  email VARCHAR(128) DEFAULT NULL,
  phone VARCHAR(32) DEFAULT NULL,
  gender INT DEFAULT NULL COMMENT '0/1/2, see application enum',
  user_type INT NOT NULL COMMENT '1-job seeker, 2-HR, 3-admin',
  status INT NOT NULL DEFAULT 1 COMMENT '0-disabled, 1-active',
  avatar_url VARCHAR(512) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  last_login_at DATETIME DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_user_username (username),
  UNIQUE KEY uk_user_email (email),
  UNIQUE KEY uk_user_phone (phone),
  KEY idx_user_type_status (user_type, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS company (
  id BIGINT NOT NULL AUTO_INCREMENT,
  owner_user_id BIGINT DEFAULT NULL,
  company_name VARCHAR(160) NOT NULL,
  description TEXT,
  company_scale INT DEFAULT NULL,
  financing_stage INT DEFAULT NULL,
  industry VARCHAR(128) DEFAULT NULL,
  website VARCHAR(255) DEFAULT NULL,
  logo_url VARCHAR(512) DEFAULT NULL,
  benefits TEXT,
  status INT NOT NULL DEFAULT 0 COMMENT '0-unverified, 1-verified',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  company_created_at DATE DEFAULT NULL,
  registered_capital INT DEFAULT NULL,
  audit_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  audited_at DATETIME DEFAULT NULL,
  PRIMARY KEY (id),
  KEY idx_company_owner_user_id (owner_user_id),
  KEY idx_company_name (company_name),
  KEY idx_company_audit_status (audit_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS hr_info (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  company_id BIGINT DEFAULT NULL,
  real_name VARCHAR(64) NOT NULL,
  position VARCHAR(128) DEFAULT NULL,
  work_phone VARCHAR(32) DEFAULT NULL,
  is_company_admin INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_hr_info_user_id (user_id),
  KEY idx_hr_info_company_id (company_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS hr_audit_record (
  id BIGINT NOT NULL AUTO_INCREMENT,
  hr_id BIGINT DEFAULT NULL,
  user_id BIGINT DEFAULT NULL,
  company_id BIGINT DEFAULT NULL,
  hr_name VARCHAR(64) DEFAULT NULL,
  audit_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  auditor_id BIGINT DEFAULT NULL,
  auditor_name VARCHAR(64) DEFAULT NULL,
  audit_reason TEXT,
  reject_reason TEXT,
  audited_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_hr_audit_hr_id (hr_id),
  KEY idx_hr_audit_user_id (user_id),
  KEY idx_hr_audit_company_id (company_id),
  KEY idx_hr_audit_status (audit_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS job_info (
  id BIGINT NOT NULL AUTO_INCREMENT,
  company_id BIGINT NOT NULL,
  hr_id BIGINT NOT NULL,
  job_title VARCHAR(160) NOT NULL,
  job_category VARCHAR(128) DEFAULT NULL,
  department VARCHAR(128) DEFAULT NULL,
  city VARCHAR(64) DEFAULT NULL,
  address VARCHAR(255) DEFAULT NULL,
  salary_min DECIMAL(12,2) DEFAULT NULL,
  salary_max DECIMAL(12,2) DEFAULT NULL,
  salary_months INT DEFAULT NULL,
  education_required INT DEFAULT NULL,
  job_type INT DEFAULT NULL COMMENT '1-intern, 2-full-time',
  experience_required INT DEFAULT NULL,
  internship_days_per_week INT DEFAULT NULL,
  internship_duration_months INT DEFAULT NULL,
  description TEXT,
  responsibilities TEXT,
  requirements TEXT,
  status INT NOT NULL DEFAULT 1 COMMENT '0-offline, 1-recruiting, 2-paused',
  view_count INT NOT NULL DEFAULT 0,
  application_count INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  published_at DATETIME DEFAULT NULL,
  audit_status VARCHAR(32) NOT NULL DEFAULT 'draft',
  company_audit_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  submitted_at DATETIME DEFAULT NULL,
  audited_at DATETIME DEFAULT NULL,
  PRIMARY KEY (id),
  KEY idx_job_company_id (company_id),
  KEY idx_job_hr_id (hr_id),
  KEY idx_job_status_type_city (status, job_type, city),
  KEY idx_job_audit_status (audit_status),
  KEY idx_job_company_audit_status (company_audit_status),
  KEY idx_job_published_at (published_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS job_skill_requirement (
  id BIGINT NOT NULL AUTO_INCREMENT,
  job_id BIGINT NOT NULL,
  skill_name VARCHAR(128) NOT NULL,
  is_required INT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_job_skill_job_id (job_id),
  KEY idx_job_skill_name (skill_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS job_seeker (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  real_name VARCHAR(64) NOT NULL,
  birth_date DATE DEFAULT NULL,
  current_city VARCHAR(64) DEFAULT NULL,
  education INT DEFAULT NULL,
  job_status INT DEFAULT NULL,
  graduation_year VARCHAR(16) DEFAULT NULL,
  internship_experience TINYINT(1) NOT NULL DEFAULT 0,
  work_experience_year INT DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_job_seeker_user_id (user_id),
  KEY idx_job_seeker_city (current_city),
  KEY idx_job_seeker_education (education),
  KEY idx_job_seeker_status (job_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS education_experience (
  id BIGINT NOT NULL AUTO_INCREMENT,
  job_seeker_id BIGINT NOT NULL,
  school_name VARCHAR(160) NOT NULL,
  major VARCHAR(160) DEFAULT NULL,
  education INT DEFAULT NULL,
  start_year DATE DEFAULT NULL,
  end_year DATE DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_education_job_seeker_id (job_seeker_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS work_experience (
  id BIGINT NOT NULL AUTO_INCREMENT,
  job_seeker_id BIGINT NOT NULL,
  company_name VARCHAR(160) NOT NULL,
  position VARCHAR(128) DEFAULT NULL,
  department VARCHAR(128) DEFAULT NULL,
  start_date DATE DEFAULT NULL,
  end_date DATE DEFAULT NULL,
  is_internship TINYINT(1) NOT NULL DEFAULT 0,
  description TEXT,
  achievements TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_work_job_seeker_id (job_seeker_id),
  KEY idx_work_is_internship (is_internship)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS project_experience (
  id BIGINT NOT NULL AUTO_INCREMENT,
  job_seeker_id BIGINT NOT NULL,
  project_name VARCHAR(160) NOT NULL,
  project_role VARCHAR(128) DEFAULT NULL,
  start_date DATE DEFAULT NULL,
  end_date DATE DEFAULT NULL,
  description TEXT,
  responsibility TEXT,
  achievement TEXT,
  responsibilities TEXT,
  achievements TEXT,
  project_url VARCHAR(512) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_project_job_seeker_id (job_seeker_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS skill (
  id BIGINT NOT NULL AUTO_INCREMENT,
  job_seeker_id BIGINT NOT NULL,
  skill_name VARCHAR(128) NOT NULL,
  level TINYINT DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_skill_job_seeker_id (job_seeker_id),
  KEY idx_skill_name (skill_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS resume (
  id BIGINT NOT NULL AUTO_INCREMENT,
  job_seeker_id BIGINT NOT NULL,
  resume_name VARCHAR(160) NOT NULL,
  privacy_level TINYINT NOT NULL DEFAULT 1,
  file_url VARCHAR(512) DEFAULT NULL,
  completeness INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_resume_job_seeker_id (job_seeker_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS job_seeker_expectation (
  id BIGINT NOT NULL AUTO_INCREMENT,
  job_seeker_id BIGINT NOT NULL,
  expected_position VARCHAR(160) DEFAULT NULL,
  expected_industry VARCHAR(128) DEFAULT NULL,
  work_city VARCHAR(64) DEFAULT NULL,
  salary_min DECIMAL(12,2) DEFAULT NULL,
  salary_max DECIMAL(12,2) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_expectation_job_seeker_id (job_seeker_id),
  KEY idx_expectation_city_salary (work_city, salary_min, salary_max)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS job_favorite (
  id BIGINT NOT NULL AUTO_INCREMENT,
  job_seeker_id BIGINT NOT NULL,
  job_id BIGINT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_favorite_seeker_job (job_seeker_id, job_id),
  KEY idx_favorite_job_id (job_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS conversation (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user1_id BIGINT NOT NULL,
  user2_id BIGINT NOT NULL,
  last_message TEXT,
  last_message_time DATETIME DEFAULT NULL,
  unread_count_user1 INT NOT NULL DEFAULT 0,
  unread_count_user2 INT NOT NULL DEFAULT 0,
  pinned_by_user1 TINYINT NOT NULL DEFAULT 0,
  pinned_by_user2 TINYINT NOT NULL DEFAULT 0,
  has_notification_user1 TINYINT NOT NULL DEFAULT 0,
  has_notification_user2 TINYINT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_by_user1 TINYINT NOT NULL DEFAULT 0,
  deleted_by_user2 TINYINT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_conversation_user1 (user1_id),
  KEY idx_conversation_user2 (user2_id),
  KEY idx_conversation_users (user1_id, user2_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS chat_message (
  id BIGINT NOT NULL AUTO_INCREMENT,
  conversation_id BIGINT NOT NULL,
  sender_id BIGINT NOT NULL,
  receiver_id BIGINT NOT NULL,
  message_type INT NOT NULL,
  content TEXT,
  file_url VARCHAR(512) DEFAULT NULL,
  reply_to BIGINT DEFAULT NULL,
  is_read TINYINT NOT NULL DEFAULT 0,
  is_flagged TINYINT NOT NULL DEFAULT 0,
  is_deleted TINYINT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_chat_conversation_id (conversation_id),
  KEY idx_chat_sender_id (sender_id),
  KEY idx_chat_receiver_id (receiver_id),
  KEY idx_chat_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS application (
  id BIGINT NOT NULL AUTO_INCREMENT,
  job_id BIGINT NOT NULL,
  job_seeker_id BIGINT NOT NULL,
  resume_id BIGINT DEFAULT NULL,
  conversation_id BIGINT DEFAULT NULL,
  initiator TINYINT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 0,
  match_score DECIMAL(5,2) DEFAULT NULL,
  match_analysis LONGTEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_application_job_id (job_id),
  KEY idx_application_job_seeker_id (job_seeker_id),
  KEY idx_application_conversation_id (conversation_id),
  KEY idx_application_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS interview (
  id BIGINT NOT NULL AUTO_INCREMENT,
  application_id BIGINT NOT NULL,
  message_id BIGINT DEFAULT NULL,
  interview_type TINYINT DEFAULT NULL,
  interview_round INT DEFAULT NULL,
  interview_time DATETIME DEFAULT NULL,
  duration INT DEFAULT NULL,
  location VARCHAR(255) DEFAULT NULL,
  meeting_link VARCHAR(512) DEFAULT NULL,
  interviewer VARCHAR(128) DEFAULT NULL,
  status TINYINT NOT NULL DEFAULT 0,
  feedback TEXT,
  result TINYINT DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_interview_application_id (application_id),
  KEY idx_interview_message_id (message_id),
  KEY idx_interview_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS offer (
  id BIGINT NOT NULL AUTO_INCREMENT,
  application_id BIGINT NOT NULL,
  message_id BIGINT DEFAULT NULL,
  job_seeker_id BIGINT NOT NULL,
  hr_id BIGINT NOT NULL,
  base_salary DECIMAL(12,2) DEFAULT NULL,
  start_date DATE DEFAULT NULL,
  status TINYINT NOT NULL DEFAULT 0,
  accepted_at DATETIME DEFAULT NULL,
  rejected_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_offer_application_id (application_id),
  KEY idx_offer_message_id (message_id),
  KEY idx_offer_job_seeker_id (job_seeker_id),
  KEY idx_offer_hr_id (hr_id),
  KEY idx_offer_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS complaint (
  id BIGINT NOT NULL AUTO_INCREMENT,
  complainant_id BIGINT NOT NULL,
  complainant_type INT NOT NULL,
  target_type INT NOT NULL,
  target_id BIGINT NOT NULL,
  complaint_type INT NOT NULL,
  title VARCHAR(160) DEFAULT NULL,
  content TEXT,
  evidence LONGTEXT,
  status INT NOT NULL DEFAULT 0,
  handler_id BIGINT DEFAULT NULL,
  handle_result TEXT,
  handled_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_complaint_target (target_type, target_id),
  KEY idx_complaint_status (status),
  KEY idx_complaint_complainant (complainant_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS reports (
  id BIGINT NOT NULL AUTO_INCREMENT,
  reporter_id BIGINT NOT NULL,
  target_type INT NOT NULL COMMENT '1-user, 2-job',
  target_id BIGINT NOT NULL,
  report_type INT NOT NULL,
  reason TEXT,
  status INT NOT NULL DEFAULT 0,
  handler_id BIGINT DEFAULT NULL,
  handle_result INT DEFAULT NULL,
  handle_reason TEXT,
  handle_time DATETIME DEFAULT NULL,
  evidence_image VARCHAR(1024) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_reports_reporter_id (reporter_id),
  KEY idx_reports_target (target_type, target_id),
  KEY idx_reports_status (status),
  KEY idx_reports_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS notifications (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  type TINYINT NOT NULL,
  title VARCHAR(160) DEFAULT NULL,
  content LONGTEXT NOT NULL,
  related_id BIGINT DEFAULT NULL,
  related_type VARCHAR(64) DEFAULT NULL,
  is_read TINYINT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  read_at DATETIME DEFAULT NULL,
  PRIMARY KEY (id),
  KEY idx_notifications_user_created (user_id, created_at),
  KEY idx_notifications_user_read (user_id, is_read)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS job_audit_record (
  id BIGINT NOT NULL AUTO_INCREMENT,
  job_id BIGINT NOT NULL,
  job_title VARCHAR(160) DEFAULT NULL,
  company_id BIGINT DEFAULT NULL,
  hr_id BIGINT DEFAULT NULL,
  company_name VARCHAR(160) DEFAULT NULL,
  hr_name VARCHAR(64) DEFAULT NULL,
  audit_note TEXT,
  audit_reason TEXT,
  reject_reason TEXT,
  audit_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  auditor_id BIGINT DEFAULT NULL,
  auditor_name VARCHAR(64) DEFAULT NULL,
  audited_at DATETIME DEFAULT NULL,
  company_audit_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  company_auditor_id BIGINT DEFAULT NULL,
  company_auditor_name VARCHAR(64) DEFAULT NULL,
  company_audited_at DATETIME DEFAULT NULL,
  system_audit_status VARCHAR(32) NOT NULL DEFAULT 'pending',
  system_auditor_id BIGINT DEFAULT NULL,
  system_auditor_name VARCHAR(64) DEFAULT NULL,
  system_audited_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_job_audit_job_id (job_id),
  KEY idx_job_audit_company_id (company_id),
  KEY idx_job_audit_audit_status (audit_status),
  KEY idx_job_audit_company_status (company_audit_status),
  KEY idx_job_audit_system_status (system_audit_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ban_record (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  username VARCHAR(64) DEFAULT NULL,
  email VARCHAR(128) DEFAULT NULL,
  user_type TINYINT DEFAULT NULL,
  ban_reason TEXT,
  ban_type VARCHAR(32) NOT NULL,
  ban_days INT DEFAULT NULL,
  ban_start_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ban_end_time DATETIME DEFAULT NULL,
  ban_status VARCHAR(32) NOT NULL DEFAULT 'active',
  operator_id BIGINT DEFAULT NULL,
  operator_name VARCHAR(64) DEFAULT NULL,
  lifted_by_operator_id BIGINT DEFAULT NULL,
  lifted_by_operator_name VARCHAR(64) DEFAULT NULL,
  lift_reason TEXT,
  lifted_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ban_user_status (user_id, ban_status),
  KEY idx_ban_operator_id (operator_id),
  KEY idx_ban_end_time (ban_end_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
