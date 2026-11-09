-- Store professional credential details directly on personnel applications
-- so applicants provide them before HR review.

ALTER TABLE personnel_applications
ADD COLUMN IF NOT EXISTS license_number VARCHAR(100);

ALTER TABLE personnel_applications
ADD COLUMN IF NOT EXISTS requested_specialty VARCHAR(160);
