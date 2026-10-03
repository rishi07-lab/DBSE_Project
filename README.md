# CarePulse HMS — React + Express microservices + MySQL

The React app now talks to **real APIs** backed by your **existing** MySQL database
`hospital_management` (MySQL 8, `localhost:3306`, user `root`, password `Root` — see `backend/.env`).
Authentication is **JWT**; every role (Admin, Doctor, Patient, Laboratory Staff) has its own dashboard
and its own server-enforced permissions.

```
React (Vite :5173)  ──/api──►  API Gateway :5000 ──► auth-service      :5001  login / JWT / change password
                               (verifies JWT)     ├─► clinical-service  :5002  patients, doctors, specializations, medical records, prescriptions
                                                  ├─► pharmacy-service  :5003  medicines & stock
                                                  ├─► lab-service       :5004  lab tests, samples, reports
                                                  ├─► billing-service   :5005  bills, payments, insurance
                                                  └─► analytics-service :5006  role dashboards
                                                                  │
                                                       MySQL 8  hospital_management  (existing DB)
```
All services share the one existing database (you asked to keep using it); each service owns its own tables
and every service re-verifies the JWT, so nothing is reachable without a valid token.

## Run it (Windows)
1. Make sure MySQL is running (port 3306).
2. Double-click **`setup-and-run.bat`** — it installs packages, applies the schema changes + demo data,
   starts the backend, then the frontend. Open http://localhost:5173.

### Or manually
```bash
cd backend
npm install
npm run db:migrate:dry   # OPTIONAL: prints exactly what would change, touches nothing
npm run db:seed          # migration + demo data (safe to re-run)
npm start                # gateway :5000 + all services
npm test                 # optional end-to-end checks (creates and removes its own test rows)

cd ../DBSE_Project
npm install
npm run dev              # http://localhost:5173
```

## Role-based login (Doctor / Admin / Laboratory / Patient)
The login page first asks which area you are signing in to. Choosing one opens **that role's own username/email +
password form** (nothing is entered automatically). After the password is verified the server checks the account's
real role: a Patient signing in through "Doctor Login" is refused (403, no token issued) and the person is told which
login to use. Each role then lands on its own dashboard (Doctor / Admin / Laboratory / Patient).

- The sample accounts on each form only **fill** the fields; you still press *Sign In* (no direct dashboard entry).
- `POST /api/auth/login` accepts an optional `role` (`Doctor`, `Admin`, `Laboratory Staff`, `Patient`); without it the
  endpoint behaves as before.
- **Create an account** appears only on the Patient login and always creates a Patient. Doctor / Admin / Laboratory
  accounts cannot be self-registered (the server ignores any role sent to `/api/auth/register`).

## Patient payments
The Patient dashboard shows **Payments Made** (total paid) and **My Payment History**, and the Bills page has a
**Payment History** table. They read the patient's real rows from the `payments` table (via their bills). Payments are
still recorded by an Admin on the Payments page.

## Staff salaries & bank details (new)
- **Admin → Staff Salaries** lists every doctor and laboratory staff member. For each one the admin can set the **monthly
  salary** and **bank details** (bank, account holder, account number, IFSC, branch), pick a month, and click
  **Credit Salary** (or **Credit All Pending**) to record that the salary was credited (date, mode, reference/UTR).
  A history view per person lets the admin remove an entry made by mistake. The admin dashboard also shows a
  *Monthly Staff Payroll* card.
- **Doctor and Laboratory dashboards** show a **My Salary** card: *"Salary credited for <month>"* with amount, date and
  bank (or *"being processed"* / *"details not set up yet"*), plus the last months' credits. The account number is
  **masked** (last 4 digits only) for staff; only Admin can see/edit the full number.
- Two new tables are created automatically (`npm run db:migrate`, or when the billing service first starts):
  `staff_payroll` and `salary_payments`. Nothing existing is changed. `npm run db:seed` adds sample salary data for the
  sample doctor and lab logins only.
- API (billing service): `GET /api/payroll?month=YYYY-MM`, `PUT /api/payroll/:userId`, `POST /api/payroll/:userId/credit`,
  `POST /api/payroll/credit-all`, `GET /api/payroll/:userId/history` (Admin) · `GET /api/payroll/me` (Doctor / Lab).
- The patient dashboard and patient payment screens are unchanged.

## Individual doctor logins & personal Doctor Dashboard
Each doctor already in the database gets their own login. Nothing is created or restructured.

    cd backend
    npm run db:doctor-accounts             # dry run: lists every doctor with username / email / password
    npm run db:doctor-accounts -- --apply  # applies it

- Username: `dr.<first>.<last>` (e.g. `dr.anita.deshmukh`); email logins keep working.
- Starting password: `<Surname>@Doc<doctor_id>` (e.g. `Deshmukh@Doc2`). Only passwords that are still the shared
  `Doctor@123` are replaced; the demo login `doctor@hospital.com / Doctor@123` is left untouched.
- The Doctor Dashboard shows the logged-in doctor's profile, specialization, own patients / prescriptions / lab reports,
  and all doctors grouped by specialization. Prescriptions and Lab Reports lists show only the doctor's own rows.
- A doctor's "patients" are those with a prescription or lab report from that doctor (no assignment column exists yet).

## Self-registration (new patients)
The login page has a **Create an account** link. New users pick their own username, email and password and are
signed in immediately as a **Patient** (staff accounts are still created by an Admin).

- `POST /api/auth/register` `{name, username, email, phone?, password}` → `{token, user}` (public, rate-limited)
- Username: 3-30 chars (`a-z 0-9 . _ -`), unique. Password: 8+ chars with a letter and a number, stored as a bcrypt hash.
- Everyone can now sign in with **username or email** (`POST /api/auth/login`).
- A `users.username` column is added automatically (by `db:migrate` or when the auth service starts).

## Sample logins
| Role | Email | Password | Dashboard |
|---|---|---|---|
| Admin | admin@hospital.com | `admin123` (your existing password, unchanged) | Admin dashboard |
| Doctor | doctor@hospital.com | `Doctor@123` | Doctor dashboard (Dr. Rajesh Sharma) |
| Patient | patient@hospital.com | `Patient@123` | Patient dashboard (Ramesh Kumar Verma) |
| Lab Staff | lab@hospital.com | `Lab@123` | Laboratory dashboard |

Your **existing** users keep their old passwords (e.g. `doctor123`, `pass123`) — they were converted to bcrypt
hashes, so the same passwords still work. Accounts created from the UI get `DEFAULT_PATIENT_PASSWORD` /
`DEFAULT_DOCTOR_PASSWORD` from `backend/.env`.

## What was changed in your database (nothing is dropped or deleted)
`npm run db:migrate:dry` shows this list live. Summary:
- `users`: `password` now stores bcrypt hashes (plain-text values are hashed in place); `phone` widened to 20.
  New role value `LAB` (lab staff).
- `patients`: + `city`, + `medical_history`; `emergency_contact` widened to 100.
- `doctors`: + `specialization_id` (FK to `specializations`) filled from your existing text specialization;
  the old text column is kept (made nullable) and kept in sync.
- `lab_tests`: + `sample_type`, + `test_status`. `lab_reports`: + `file_attachment`, + `file_size`.
- `lab_samples`: your existing table is kept; missing columns are added (`sample_code`, `collection_date`, …).
- Demo data is **added alongside** yours (+1 lab user, +12 doctors, +10 patients, +12 medicines, 5 prescriptions, 3 records,
  5 lab samples, 3 lab reports, 5 bills, 3 payments, 4 policies). Rows are matched by natural keys, so re-running adds nothing twice.
- Demo data was normalised to match yours: 10-digit phones, medicine category `Tablet`, payment methods `UPI`/`Card`/`Cash`,
  existing lab-test names reused (no duplicate "Lipid Profile" etc.), specialization names aligned (`Gynecology`, `ENT`).

## Who can do what (enforced on the server)
| Resource | Admin | Doctor | Lab Staff | Patient |
|---|---|---|---|---|
| patients | R/W | R/W | R | own only (R) |
| doctors, specializations | R/W | R | R | – |
| medical records, prescriptions | – | R/W | – | own only (R) |
| medicines | R/W | R | – | – |
| lab tests | R/W | R | R/W | – |
| lab samples | – | R | R/W | – |
| lab reports | – | R/W | R/W | own only (R) |
| bills, payments, insurance | R/W | – | – | own only (R) |
| dashboards | admin | doctor | lab | patient |

## API (all under the gateway, `Authorization: Bearer <token>` except login)
- `POST /api/auth/login` `{email,password}` → `{token,user}` · `GET /api/auth/me` · `POST /api/auth/change-password`
- REST resources (`GET /`, `GET /:id`, `POST /`, `PUT /:id`, `DELETE /:id` where allowed):
  `/api/patients` `/api/doctors` `/api/specializations` `/api/medical-records` `/api/prescriptions`
  `/api/medicines` `/api/lab-tests` `/api/lab-samples` `/api/lab-reports` `/api/bills` `/api/payments` `/api/insurance`
- `GET /api/dashboard/{admin|doctor|patient|lab}` · `GET /api/health` (aggregated service health, public)

Errors are JSON `{message}` with proper codes: 400 validation, 401 no/expired token, 403 wrong role,
404, 409 duplicate or "still referenced by other records" (deleting something in use is refused, never cascaded).

## Docker (optional)
MySQL is **not** containerised — containers reach your existing MySQL via `host.docker.internal:3306`.
```bash
docker compose --profile tools run --rm db-seed   # one-time: migration + demo data
docker compose up --build                         # app on http://localhost:8080, gateway on :5000
```
MySQL must accept connections from Docker (check `bind-address` and that `root` may connect from the Docker network).

## Notes / limits
- Uploading a lab report stores the record (file name, size, findings), not the file itself — add S3/disk storage later.
- Change `JWT_SECRET` in `backend/.env` before any real deployment (a random one was generated for you), and use a
  non-root MySQL user with a real password outside local development.
- There is no appointment booking, by design (as in the original app).

## Extra demo data & doctor stats
`npm run db:seed` also runs `db/seed-extra.js` (or run `npm run db:seed-extra` alone, any time; safe to re-run):
- every doctor gets 10 new patients **of their own specialization** (e.g. Cardiology: hypertension / angina patients with
  ECG + lipid reports and cardiac medicines; Orthopedics: knee / spine patients with X-ray + MRI), each with medical records,
  prescriptions, lab reports, bills and payments
- every doctor gets patients seen today and operations: 3 today, 3 completed, 3 upcoming (procedures match the specialization)
- existing patients with no data (e.g. Ramesh Kumar Verma) are filled and assigned to a doctor of the matching specialization
- a doctor only sees patients they treated, so each doctor sees patients of their own field
- Doctor dashboard: **Patients Seen** (today / this month), **Operations Today**, **Today's Operations** table;
  Admin dashboard: **Operations Today**. Re-run `npm run db:seed-extra` each day to get fresh "today" operations.

## Choosing a password when creating accounts (new)
- **Doctors** (Admin -> Doctors -> Add), **Patients** (Doctor -> Patients -> Register) and **Laboratory staff**
  (Admin -> **Lab Staff Accounts** -> Add Lab Staff) now all ask for a **Login Password** (required, min 8 chars with a letter
  and a number; Show / Generate buttons included). After creating, a message shows the login (email) and password.
- Sign in with the **email + the password you set** on the matching login page (Doctor / Patient / Laboratory).
- Editing an account has an optional **Reset Password** box (blank = unchanged).
- Lab staff API (Admin only): `GET/POST /api/auth/staff/lab`, `PUT/DELETE /api/auth/staff/lab/:id`.
- Email must be unique; a duplicate email now returns a clear message.
