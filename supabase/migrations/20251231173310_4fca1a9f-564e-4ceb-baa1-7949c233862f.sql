INSERT INTO public.user_roles (user_id, role)
SELECT id, 'admin'::app_role
FROM auth.users
WHERE id = '78657387-d518-4b2e-88d8-eca802372ad5'
ON CONFLICT (user_id, role) DO NOTHING;
