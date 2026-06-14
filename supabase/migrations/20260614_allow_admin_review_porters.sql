DROP POLICY IF EXISTS "anon can read verifikasi"
  ON public.porter_verifikasi;

CREATE POLICY "anon can read verifikasi"
  ON public.porter_verifikasi FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Admin app baca profil porter untuk verifikasi"
  ON public.porters;

CREATE POLICY "Admin app baca profil porter untuk verifikasi"
  ON public.porters FOR SELECT
  TO anon, authenticated
  USING (true);
