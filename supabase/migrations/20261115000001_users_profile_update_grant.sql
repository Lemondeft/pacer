-- Restore authenticated column-level UPDATE privileges on user-editable profile
-- columns (About Me / Tentang Saya & language preference) while keeping id,
-- peran, and created_at non-updatable by regular clients.

grant update (
  nama,
  language,
  lahir,
  jenis_kelamin,
  tinggi_cm,
  berat_kg,
  region
) on public.users to authenticated;
