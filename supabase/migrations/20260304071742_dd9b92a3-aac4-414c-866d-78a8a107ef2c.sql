INSERT INTO public.user_roles (user_id, role)
SELECT id, 'admin'::app_role
FROM auth.users
WHERE id = 'c4642966-5969-4d55-b3a6-ce850c1e2786'
ON CONFLICT (user_id, role) DO NOTHING;
