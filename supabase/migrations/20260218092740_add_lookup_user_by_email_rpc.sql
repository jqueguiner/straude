-- Secure function to look up a user's public.users ID by their auth email.
-- Uses SECURITY DEFINER to access auth.users (not exposed to clients directly).
-- Only returns the ID — caller must still query public.users for profile data.
CREATE OR REPLACE FUNCTION public.lookup_user_id_by_email(p_email text)
  RETURNS uuid
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  found_id uuid;
BEGIN
  SELECT id INTO found_id
  FROM auth.users
  WHERE email = lower(p_email)
  LIMIT 1;
  RETURN found_id;
END;
$$;

-- Only allow authenticated users to call this function
REVOKE ALL ON FUNCTION public.lookup_user_id_by_email(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.lookup_user_id_by_email(text) TO authenticated;;
