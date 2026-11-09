-- No mandatory documents are invented or seeded. HR must define each role.
CREATE TABLE IF NOT EXISTS professional_document_requirements (
  role_code VARCHAR(60) PRIMARY KEY REFERENCES roles(code),
  document_types JSONB NOT NULL CHECK (
    jsonb_typeof(document_types)='array' AND jsonb_array_length(document_types)>0
  ),
  updated_by_user_id UUID NOT NULL REFERENCES users(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE professional_documents ADD COLUMN IF NOT EXISTS valid_until DATE;
ALTER TABLE professionals ADD COLUMN IF NOT EXISTS pending_specialty_id UUID REFERENCES specialties(id);

ALTER TABLE professional_document_requirements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS requirements_read ON professional_document_requirements;
CREATE POLICY requirements_read ON professional_document_requirements
FOR SELECT USING (app_current_user_id() IS NOT NULL);
DROP POLICY IF EXISTS requirements_manage ON professional_document_requirements;
CREATE POLICY requirements_manage ON professional_document_requirements
FOR ALL USING (app_has_permission('human_resources.manage'))
WITH CHECK (app_has_permission('human_resources.manage'));

ALTER TABLE professional_specialties ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS professional_specialties_read ON professional_specialties;
CREATE POLICY professional_specialties_read ON professional_specialties
FOR SELECT USING (app_current_user_id() IS NOT NULL);
DROP POLICY IF EXISTS professional_specialties_review ON professional_specialties;
CREATE POLICY professional_specialties_review ON professional_specialties
FOR ALL USING (app_has_permission('human_resources.manage'))
WITH CHECK (app_has_permission('human_resources.manage'));
