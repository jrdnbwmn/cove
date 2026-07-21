Cove app

## Dev login credentials

Run `bin/rails db:seed` to create the following personas. All use the shared
password `password` and are pre-confirmed, so you can sign in immediately.

| Email | Name | Notes |
|---|---|---|
| `owner@cove.test` | Olivia Owner | Owns "Cove Team", team admin |
| `admin@cove.test` | Andy Admin | "Cove Team" admin (non-owner) |
| `member@cove.test` | Molly Member | "Cove Team" member (no admin) |
| `subscribed@cove.test` | Sofia Subscriber | Active fake-processor subscription |
| `superadmin@cove.test` | Sydney Super | System admin (`/admin`) |
