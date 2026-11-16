-- DDL Healthcare clinic

CREATE SCHEMA IF NOT EXISTS healthcare_clinic;
SET search_path TO healthcare_clinic, public;

-- TYPES: 
-- INTEGER identity fits educational row counts; production-scale systems
-- may require BIGINT to avoid exhausting IDs. VARCHAR limits text length, DATE
-- stores calendar dates, TIMESTAMP stores date/time without timezone (the logical
-- model's type); production multi-zone systems should consider TIMESTAMPTZ to
-- prevent ambiguous local times. NUMERIC(12,2) avoids FLOAT rounding for money.
-- Wrong types can cause overflow, rounding, truncation, timezone ambiguity,
-- invalid comparisons, or loss of precision.
-- Parent tables must exist before referencing children; otherwise PostgreSQL
-- raises ERROR: relation "..." does not exist when creating an FK.
-- FKs reject orphan rows; without them, a visit could reference a nonexistent
-- appointment, or a payment a nonexistent invoice.
-- PKs and UNIQUE prevent duplicate identities; NOT NULL prevents missing required
-- facts; CHECK prevents invalid values. Without these, inconsistent or impossible
-- records could be stored. CHECK is evaluated only on INSERT/UPDATE; NULL requires
-- separate NOT NULL (CHECK alone allows NULL).


CREATE TABLE IF NOT EXISTS patients (
    patient_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medical_record_number VARCHAR(30) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_patient_birth_after_2000 CHECK (date_of_birth > DATE '2000-01-01')
);


CREATE TABLE IF NOT EXISTS staff (
    staff_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL,
    specialization VARCHAR(100),
    email VARCHAR(255) UNIQUE,
    hired_at DATE NOT NULL,
    CONSTRAINT chk_staff_role CHECK (role IN ('doctor','nurse','receptionist','administrator'))
);


CREATE TABLE IF NOT EXISTS diagnoses (
    diagnosis_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    diagnosis_code VARCHAR(20) NOT NULL UNIQUE,
    diagnosis_name VARCHAR(255) NOT NULL,
    description TEXT
);

CREATE TABLE IF NOT EXISTS medications (
    medication_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medication_name VARCHAR(150) NOT NULL,
    strength VARCHAR(50),
    dosage_form VARCHAR(50)
);


CREATE TABLE IF NOT EXISTS patient_history (
    history_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(patient_id),
    phone VARCHAR(20),
    email VARCHAR(255),
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by INTEGER NOT NULL REFERENCES staff(staff_id)
);

CREATE TABLE IF NOT EXISTS staff_history (
    history_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    staff_id INTEGER NOT NULL REFERENCES staff(staff_id),
    role VARCHAR(50) NOT NULL,
    specialization VARCHAR(100),
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by INTEGER NOT NULL REFERENCES staff(staff_id),
    CONSTRAINT chk_staff_history_role CHECK (role IN ('doctor','nurse','receptionist','administrator'))
);

CREATE TABLE IF NOT EXISTS staff_schedules (
    schedule_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    staff_id INTEGER NOT NULL REFERENCES staff(staff_id),
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_schedule_order CHECK (end_time > start_time)
);

CREATE TABLE IF NOT EXISTS appointments (
    appointment_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(patient_id),
    doctor_id INTEGER NOT NULL REFERENCES staff(staff_id),
    scheduled_start TIMESTAMP NOT NULL,
    scheduled_end TIMESTAMP NOT NULL,
    reason TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'scheduled',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_appointment_order CHECK (scheduled_end > scheduled_start),
    CONSTRAINT chk_appointment_status CHECK (status IN ('scheduled','completed','cancelled','missed'))
);

CREATE TABLE IF NOT EXISTS appointment_history (
    history_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id INTEGER NOT NULL REFERENCES appointments(appointment_id),
    status VARCHAR(30) NOT NULL,
    scheduled_start TIMESTAMP NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    doctor_id INTEGER NOT NULL REFERENCES staff(staff_id),
    scheduled_end TIMESTAMP NOT NULL,
    reason TEXT,
    changed_by INTEGER NOT NULL REFERENCES staff(staff_id),
    CONSTRAINT chk_appointment_history_order CHECK (scheduled_end > scheduled_start),
    CONSTRAINT chk_appointment_history_status CHECK (status IN ('scheduled','completed','cancelled','missed'))
);

CREATE TABLE IF NOT EXISTS visits (
    visit_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id INTEGER NOT NULL UNIQUE REFERENCES appointments(appointment_id),
    visit_date TIMESTAMP NOT NULL,
    clinical_notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS visit_history (
    visit_history_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    visit_id INTEGER NOT NULL REFERENCES visits(visit_id),
    clinical_notes TEXT,
    recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    recorded_by INTEGER NOT NULL REFERENCES staff(staff_id),
    change_reason TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS visit_diagnoses (
    visit_id INTEGER NOT NULL REFERENCES visits(visit_id),
    diagnosis_id INTEGER NOT NULL REFERENCES diagnoses(diagnosis_id),
    diagnosed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    PRIMARY KEY (visit_id, diagnosis_id)
);

CREATE TABLE IF NOT EXISTS treatments (
    treatment_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    visit_id INTEGER NOT NULL REFERENCES visits(visit_id),
    treatment_name VARCHAR(150) NOT NULL,
    description TEXT,
    performed_at TIMESTAMP,
    status VARCHAR(30) NOT NULL DEFAULT 'planned',
    CONSTRAINT chk_treatment_status CHECK (status IN ('planned','in_progress','completed','cancelled')),
    CONSTRAINT chk_treatment_completed CHECK (status <> 'completed' OR performed_at IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS treatment_history (
    history_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    treatment_id INTEGER NOT NULL REFERENCES treatments(treatment_id),
    status VARCHAR(30) NOT NULL,
    description TEXT,
    performed_at TIMESTAMP,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by INTEGER NOT NULL REFERENCES staff(staff_id),
    CONSTRAINT chk_treatment_history_status CHECK (status IN ('planned','in_progress','completed','cancelled'))
);

CREATE TABLE IF NOT EXISTS prescriptions (
    prescription_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    visit_id INTEGER NOT NULL REFERENCES visits(visit_id),
    medication_id INTEGER NOT NULL REFERENCES medications(medication_id),
    dosage_instructions TEXT NOT NULL,
    prescribed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    start_date DATE,
    end_date DATE,
    CONSTRAINT chk_prescription_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS diagnostic_tests (
    test_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    visit_id INTEGER NOT NULL REFERENCES visits(visit_id),
    test_name VARCHAR(150) NOT NULL,
    ordered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    result TEXT,
    result_recorded_at TIMESTAMP,
    status VARCHAR(30) NOT NULL DEFAULT 'ordered',
    CONSTRAINT chk_test_status CHECK (status IN ('ordered','in_progress','completed','cancelled')),
    CONSTRAINT chk_test_result_time CHECK (result_recorded_at IS NULL OR result_recorded_at >= ordered_at)
);

CREATE TABLE IF NOT EXISTS diagnostic_test_history (
    history_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    test_id INTEGER NOT NULL REFERENCES diagnostic_tests(test_id),
    status VARCHAR(30) NOT NULL,
    result TEXT,
    result_recorded_at TIMESTAMP,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by INTEGER NOT NULL REFERENCES staff(staff_id),
    CONSTRAINT chk_test_history_status CHECK (status IN ('ordered','in_progress','completed','cancelled'))
);

CREATE TABLE IF NOT EXISTS invoices (
    invoice_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    visit_id INTEGER NOT NULL UNIQUE REFERENCES visits(visit_id),
    issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMERIC(12,2) NOT NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'AMD',
    CONSTRAINT chk_invoice_amount CHECK (total_amount >= 0)
);

CREATE TABLE IF NOT EXISTS payments (
    payment_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_id INTEGER NOT NULL REFERENCES invoices(invoice_id),
    amount NUMERIC(12,2) NOT NULL,
    paid_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payment_method VARCHAR(30) NOT NULL,
    transaction_reference VARCHAR(100) UNIQUE,
    CONSTRAINT chk_payment_positive CHECK (amount > 0),
    CONSTRAINT chk_payment_method CHECK (payment_method IN ('cash','card','bank_transfer'))
);


-- Indexes on FK lookup columns
CREATE INDEX IF NOT EXISTS ix_patient_history_patient ON patient_history(patient_id);

CREATE INDEX IF NOT EXISTS ix_patient_history_staff ON patient_history(changed_by);

CREATE INDEX IF NOT EXISTS ix_staff_history_staff ON staff_history(staff_id);

CREATE INDEX IF NOT EXISTS ix_staff_history_editor ON staff_history(changed_by);

CREATE INDEX IF NOT EXISTS ix_schedule_staff ON staff_schedules(staff_id);

CREATE INDEX IF NOT EXISTS ix_appointment_patient ON appointments(patient_id);

CREATE INDEX IF NOT EXISTS ix_appointment_doctor ON appointments(doctor_id);

CREATE INDEX IF NOT EXISTS ix_appointment_history_appointment ON appointment_history(appointment_id);

CREATE INDEX IF NOT EXISTS ix_appointment_history_doctor ON appointment_history(doctor_id);

CREATE INDEX IF NOT EXISTS ix_appointment_history_editor ON appointment_history(changed_by);

CREATE INDEX IF NOT EXISTS ix_visit_history_visit ON visit_history(visit_id);

CREATE INDEX IF NOT EXISTS ix_visit_history_staff ON visit_history(recorded_by);

CREATE INDEX IF NOT EXISTS ix_visit_diagnoses_diagnosis ON visit_diagnoses(diagnosis_id);

CREATE INDEX IF NOT EXISTS ix_treatments_visit ON treatments(visit_id);

CREATE INDEX IF NOT EXISTS ix_treatment_history_treatment ON treatment_history(treatment_id);

CREATE INDEX IF NOT EXISTS ix_treatment_history_staff ON treatment_history(changed_by);

CREATE INDEX IF NOT EXISTS ix_prescriptions_visit ON prescriptions(visit_id);

CREATE INDEX IF NOT EXISTS ix_prescriptions_medication ON prescriptions(medication_id);

CREATE INDEX IF NOT EXISTS ix_tests_visit ON diagnostic_tests(visit_id);

CREATE INDEX IF NOT EXISTS ix_test_history_test ON diagnostic_test_history(test_id);

CREATE INDEX IF NOT EXISTS ix_test_history_staff ON diagnostic_test_history(changed_by);

CREATE INDEX IF NOT EXISTS ix_payments_invoice ON payments(invoice_id);

-- SAMPLE DATA

INSERT INTO patients (medical_record_number, first_name, last_name, date_of_birth, phone, email)
VALUES ('MRN-DEMO-001','Anna','Smith','2001-03-14','011288888','anna.demo@example.com'),
    ('MRN-DEMO-002','Aram','Petrosyan','2002-07-19','011299999','aram.demo@example.com')
ON CONFLICT DO NOTHING;

INSERT INTO staff (first_name,last_name,role,specialization,email,hired_at)
VALUES ('Mariam','Hakobyan','doctor','Cardiology','mariam.demo@clinic.example','2022-04-01'),
    ('Lilit','Sargsyan','doctor','General Medicine','lilit.demo@clinic.example','2021-09-10')
ON CONFLICT DO NOTHING;

INSERT INTO diagnoses (diagnosis_code,diagnosis_name,description)
VALUES ('I10','Hypertension','High blood pressure'),('J00','Common cold','Acute nasopharyngitis')
ON CONFLICT DO NOTHING;

INSERT INTO medications (medication_name,strength,dosage_form)

SELECT v.name,v.strength,v.form FROM (VALUES
    ('Paracetamol','500 mg','tablet'),
    ('Ibuprofen','200 mg','tablet')) v(name,
    strength,
    form)
WHERE NOT EXISTS (SELECT 1 FROM medications m WHERE m.medication_name=v.name AND m.strength=v.strength AND m.dosage_form=v.form)
ON CONFLICT DO NOTHING;

INSERT INTO patient_history (patient_id,phone,email,changed_at,changed_by)

SELECT p.patient_id,p.phone,p.email,TIMESTAMP '2026-10-20 09:00',s.staff_id
FROM patients p JOIN staff s ON s.email = CASE p.medical_record_number
    WHEN 'MRN-DEMO-001' THEN 'mariam.demo@clinic.example'
    WHEN 'MRN-DEMO-002' THEN 'lilit.demo@clinic.example' END
WHERE p.medical_record_number IN ('MRN-DEMO-001','MRN-DEMO-002')
    AND NOT EXISTS (SELECT 1 FROM patient_history h WHERE h.patient_id=p.patient_id AND h.changed_at=TIMESTAMP '2026-10-20 09:00')
ON CONFLICT DO NOTHING;

INSERT INTO staff_history (staff_id,role,specialization,changed_at,changed_by)

SELECT s.staff_id,s.role,s.specialization,TIMESTAMP '2026-10-20 09:10',s.staff_id
FROM staff s WHERE s.email IN ('mariam.demo@clinic.example','lilit.demo@clinic.example')
AND NOT EXISTS (SELECT 1 FROM staff_history h WHERE h.staff_id=s.staff_id AND h.changed_at=TIMESTAMP '2026-10-20 09:10')
ON CONFLICT DO NOTHING;

INSERT INTO staff_schedules (staff_id,start_time,end_time)

SELECT s.staff_id,v.start_time,v.end_time
FROM (VALUES ('mariam.demo@clinic.example',TIMESTAMP '2026-10-25 09:00',TIMESTAMP '2026-10-25 17:00'),
('lilit.demo@clinic.example',TIMESTAMP '2026-10-26 09:00',TIMESTAMP '2026-10-26 17:00')) v(email,start_time,end_time)
JOIN staff s ON s.email=v.email
WHERE NOT EXISTS (SELECT 1 FROM staff_schedules sc WHERE sc.staff_id=s.staff_id AND sc.start_time=v.start_time)
ON CONFLICT DO NOTHING;

INSERT INTO appointments (patient_id,doctor_id,scheduled_start,scheduled_end,reason,status)

SELECT p.patient_id,s.staff_id,v.start_time,v.end_time,v.reason,'completed'
FROM (VALUES ('MRN-DEMO-001','mariam.demo@clinic.example',TIMESTAMP '2026-10-25 10:00',TIMESTAMP '2026-10-25 10:30','Routine check-up'),
('MRN-DEMO-002','lilit.demo@clinic.example',TIMESTAMP '2026-10-26 11:00',TIMESTAMP '2026-10-26 11:30','Cold symptoms')) v(mrn,doctor_email,start_time,end_time,reason)
JOIN patients p ON p.medical_record_number=v.mrn JOIN staff s ON s.email=v.doctor_email
WHERE NOT EXISTS (SELECT 1 FROM appointments a WHERE a.patient_id=p.patient_id AND a.scheduled_start=v.start_time)
ON CONFLICT DO NOTHING;

INSERT INTO appointment_history (appointment_id,status,scheduled_start,doctor_id,scheduled_end,reason,changed_by,changed_at)

SELECT a.appointment_id,'scheduled',a.scheduled_start,a.doctor_id,a.scheduled_end,a.reason,a.doctor_id,TIMESTAMP '2026-10-20 09:30'
FROM appointments a JOIN patients p ON p.patient_id=a.patient_id
WHERE p.medical_record_number IN ('MRN-DEMO-001','MRN-DEMO-002')
AND NOT EXISTS (SELECT 1 FROM appointment_history h WHERE h.appointment_id=a.appointment_id AND h.changed_at=TIMESTAMP '2026-10-20 09:30')
ON CONFLICT DO NOTHING;

INSERT INTO visits (appointment_id,visit_date,clinical_notes)

SELECT a.appointment_id,a.scheduled_start,v.notes
FROM appointments a JOIN patients p ON p.patient_id=a.patient_id
JOIN (VALUES ('MRN-DEMO-001','Routine consultation'),('MRN-DEMO-002','Respiratory consultation')) v(mrn,notes)
ON p.medical_record_number=v.mrn
ON CONFLICT DO NOTHING;

INSERT INTO visit_history (visit_id,clinical_notes,recorded_at,recorded_by,change_reason)

SELECT v.visit_id,v.clinical_notes,v.visit_date,a.doctor_id,'Initial clinical notes recorded'
FROM visits v JOIN appointments a ON a.appointment_id=v.appointment_id JOIN patients p ON p.patient_id=a.patient_id
WHERE p.medical_record_number IN ('MRN-DEMO-001','MRN-DEMO-002')
AND NOT EXISTS (SELECT 1 FROM visit_history h WHERE h.visit_id=v.visit_id AND h.recorded_at=v.visit_date)
ON CONFLICT DO NOTHING;

INSERT INTO visit_diagnoses (visit_id,diagnosis_id,diagnosed_at,notes)

SELECT v.visit_id,d.diagnosis_id,v.visit_date,'Demo diagnosis'
FROM visits v JOIN appointments a ON a.appointment_id=v.appointment_id JOIN patients p ON p.patient_id=a.patient_id
JOIN diagnoses d ON d.diagnosis_code=CASE p.medical_record_number WHEN 'MRN-DEMO-001' THEN 'I10' WHEN 'MRN-DEMO-002' THEN 'J00' END
WHERE p.medical_record_number IN ('MRN-DEMO-001','MRN-DEMO-002')
ON CONFLICT DO NOTHING;

INSERT INTO treatments (visit_id,treatment_name,description,performed_at,status)

SELECT v.visit_id, CASE p.medical_record_number WHEN 'MRN-DEMO-001' THEN 'Blood pressure monitoring' ELSE 'Symptom assessment' END,
'Demo treatment',v.visit_date,'completed'
FROM visits v JOIN appointments a ON a.appointment_id=v.appointment_id JOIN patients p ON p.patient_id=a.patient_id
WHERE p.medical_record_number IN ('MRN-DEMO-001','MRN-DEMO-002')
AND NOT EXISTS (SELECT 1 FROM treatments t WHERE t.visit_id=v.visit_id AND t.treatment_name=CASE p.medical_record_number WHEN 'MRN-DEMO-001' THEN 'Blood pressure monitoring' ELSE 'Symptom assessment' END)
ON CONFLICT DO NOTHING;

INSERT INTO treatment_history (treatment_id,status,description,performed_at,changed_at,changed_by)

SELECT t.treatment_id,'planned',t.description,NULL,v.visit_date,a.doctor_id
FROM treatments t JOIN visits v ON v.visit_id=t.visit_id JOIN appointments a ON a.appointment_id=v.appointment_id
JOIN patients p ON p.patient_id=a.patient_id
WHERE p.medical_record_number IN ('MRN-DEMO-001','MRN-DEMO-002')
AND NOT EXISTS (SELECT 1 FROM treatment_history h WHERE h.treatment_id=t.treatment_id AND h.changed_at=v.visit_date)
ON CONFLICT DO NOTHING;

INSERT INTO prescriptions (visit_id,medication_id,dosage_instructions,prescribed_at,start_date,end_date)

SELECT v.visit_id,m.medication_id,'One tablet as directed',v.visit_date,v.visit_date::date,(v.visit_date::date+3)
FROM visits v JOIN appointments a ON a.appointment_id=v.appointment_id JOIN patients p ON p.patient_id=a.patient_id
JOIN medications m ON m.medication_name=CASE p.medical_record_number WHEN 'MRN-DEMO-001' THEN 'Paracetamol' ELSE 'Ibuprofen' END
WHERE p.medical_record_number IN ('MRN-DEMO-001','MRN-DEMO-002')
AND NOT EXISTS (SELECT 1 FROM prescriptions rx WHERE rx.visit_id=v.visit_id AND rx.medication_id=m.medication_id)
ON CONFLICT DO NOTHING;

INSERT INTO diagnostic_tests (visit_id,test_name,ordered_at,result,result_recorded_at,status)

SELECT v.visit_id, CASE p.medical_record_number WHEN 'MRN-DEMO-001' THEN 'Complete blood count' ELSE 'Rapid antigen test' END,
v.visit_date,'Within reference range',v.visit_date+INTERVAL '4 hours','completed'
FROM visits v JOIN appointments a ON a.appointment_id=v.appointment_id JOIN patients p ON p.patient_id=a.patient_id
WHERE p.medical_record_number IN ('MRN-DEMO-001','MRN-DEMO-002')
AND NOT EXISTS (SELECT 1 FROM diagnostic_tests t WHERE t.visit_id=v.visit_id AND t.test_name=CASE p.medical_record_number WHEN 'MRN-DEMO-001' THEN 'Complete blood count' ELSE 'Rapid antigen test' END)
ON CONFLICT DO NOTHING;

INSERT INTO diagnostic_test_history (test_id,status,result,result_recorded_at,changed_at,changed_by)

SELECT t.test_id,'ordered',NULL,NULL,t.ordered_at,a.doctor_id
FROM diagnostic_tests t JOIN visits v ON v.visit_id=t.visit_id JOIN appointments a ON a.appointment_id=v.appointment_id
JOIN patients p ON p.patient_id=a.patient_id
WHERE p.medical_record_number IN ('MRN-DEMO-001','MRN-DEMO-002')
AND NOT EXISTS (SELECT 1 FROM diagnostic_test_history h WHERE h.test_id=t.test_id AND h.changed_at=t.ordered_at)
ON CONFLICT DO NOTHING;

INSERT INTO invoices (visit_id,issued_at,total_amount,currency_code)

SELECT v.visit_id,v.visit_date+INTERVAL '1 hour',15000.00,'AMD'
FROM visits v JOIN appointments a ON a.appointment_id=v.appointment_id JOIN patients p ON p.patient_id=a.patient_id
WHERE p.medical_record_number IN ('MRN-DEMO-001','MRN-DEMO-002')
ON CONFLICT DO NOTHING;

INSERT INTO payments (invoice_id,amount,paid_at,payment_method,transaction_reference)

SELECT i.invoice_id,10000.00,i.issued_at+INTERVAL '5 minutes','card',
CASE p.medical_record_number WHEN 'MRN-DEMO-001' THEN 'DEMO-PAY-001' ELSE 'DEMO-PAY-002' END
FROM invoices i JOIN visits v ON v.visit_id=i.visit_id JOIN appointments a ON a.appointment_id=v.appointment_id
JOIN patients p ON p.patient_id=a.patient_id
WHERE p.medical_record_number IN ('MRN-DEMO-001','MRN-DEMO-002')
ON CONFLICT DO NOTHING;

-- ALTER TABLE

ALTER TABLE patients ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE staff ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE diagnoses ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE medications ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE patient_history ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE staff_history ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE staff_schedules ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE appointments ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE appointment_history ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE visits ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE visit_history ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE visit_diagnoses ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE treatments ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE treatment_history ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE prescriptions ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE diagnostic_tests ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE diagnostic_test_history ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE invoices ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE payments ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;


DO $check$
DECLARE t RECORD; n BIGINT; missing BIGINT;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables
    WHERE table_schema='healthcare_clinic' AND table_type='BASE TABLE'
    LOOP
    EXECUTE format('SELECT count(*),count(*) FILTER (WHERE record_ts IS NULL) FROM healthcare_clinic.%I',t.table_name)
    INTO n,
    missing;
    RAISE NOTICE 'table: %, rows: %, null record_ts: %',
    t.table_name,
    n,
    missing;
    IF n<2 OR missing>0 THEN RAISE EXCEPTION 'Validation failed: %',
    t.table_name; END IF;
    END LOOP;
END $check$;

SELECT count(*) AS table_count FROM information_schema.tables
WHERE table_schema='healthcare_clinic' AND table_type='BASE TABLE';


SELECT count(*) AS foreign_key_count FROM information_schema.table_constraints
WHERE table_schema='healthcare_clinic' AND constraint_type='FOREIGN KEY';


SELECT count(*) AS tables_with_record_ts FROM information_schema.columns
WHERE table_schema='healthcare_clinic' AND column_name='record_ts'
AND is_nullable='NO' AND column_default IS NOT NULL;


-- CREATE TABLE IF NOT EXISTS does not reconcile an incompatible preexisting
-- table; run against the newly created, dedicated database for initial testing.
-- History tables preserve snapshot rows but application logic or triggers must
-- populate them when real records change; this homework does not implement triggers.
-- Additional business rules (doctor eligibility, no overlapping appointments,
-- invoice overpayment prevention) require application logic or further DB objects.


SELECT COUNT(*) AS total_tables
FROM information_schema.tables
WHERE table_schema = 'healthcare_clinic'
  AND table_type = 'BASE TABLE';


SELECT COUNT(*) AS total_foreign_keys
FROM information_schema.table_constraints
WHERE table_schema = 'healthcare_clinic'
  AND constraint_type = 'FOREIGN KEY';

  SELECT
    schemaname,
    relname AS table_name,
    n_live_tup AS estimated_rows
FROM pg_stat_user_tables
WHERE schemaname = 'healthcare_clinic'
ORDER BY relname;