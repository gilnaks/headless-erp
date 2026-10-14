-- 0117 setup: the onboarding wizard creates organizations through public.provision_organization (0116), so the P0
-- create_organization RPC is removed. app.create_organization stays as provisioning Stage A.

drop function if exists public.create_organization(jsonb);
