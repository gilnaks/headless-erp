import { createRootRoute, createRoute, createRouter, Outlet, redirect, useParams, useRouter, useRouterState } from "@tanstack/react-router";
import { NuqsAdapter } from "nuqs/adapters/tanstack-router";
import { type ReactNode, useEffect } from "react";
import { LoadingIndicator } from "@/components/application/loading-indicator/loading-indicator";
import { completeAuthCallback } from "@/lib/auth/callback";
import { safeNext } from "@/lib/auth/redirect";
import { registerNavigate } from "@/lib/navigate";
import { createClient } from "@/lib/supabase/client";
import { RouteProvider } from "@/providers/router-provider";
import { Theme } from "@/providers/theme";
import ItemPage from "@/screens/(app)/[org]/[module]/[...slug]/page";
import ModulePage from "@/screens/(app)/[org]/[module]/page";
import OrgHomePage from "@/screens/(app)/[org]/page";
import RolePermissionsPage from "@/screens/(app)/[org]/setup/role-permissions/page";
import MemberPage from "@/screens/(app)/[org]/setup/users/[userId]/page";
import UsersPage from "@/screens/(app)/[org]/setup/users/page";
import ForgotPasswordPage from "@/screens/(auth)/forgot-password/page";
import AuthLayout from "@/screens/(auth)/layout";
import LoginPage from "@/screens/(auth)/login/page";
import SignupPage from "@/screens/(auth)/signup/page";
import UpdatePasswordPage from "@/screens/(auth)/update-password/page";
import SetupPage from "@/screens/(onboarding)/setup/page";
import PrintPage from "@/screens/(print)/print/[doctype]/[id]/page";
import InvitePage from "@/screens/invite/[token]/page";
import NotFound from "@/screens/not-found";
import Home from "@/screens/page";
import { AsyncPage } from "@/spa/async-page";
import { OrgShell } from "@/spa/org-shell";

function searchRecord(searchStr: string): Record<string, string> {
    const raw = searchStr.startsWith("?") ? searchStr.slice(1) : searchStr;
    return Object.fromEntries(new URLSearchParams(raw));
}

function Root() {
    const router = useRouter();
    useEffect(() => {
        registerNavigate((to) => router.history.push(to));
    }, [router]);
    return (
        <NuqsAdapter>
            <RouteProvider>
                <Theme>
                    <Outlet />
                </Theme>
            </RouteProvider>
        </NuqsAdapter>
    );
}

function AuthScreen({ children }: { children: ReactNode }) {
    return <AuthLayout>{children}</AuthLayout>;
}

function CallbackScreen() {
    const router = useRouter();
    const searchStr = useRouterState({ select: (state) => state.location.searchStr });
    useEffect(() => {
        let active = true;
        void completeAuthCallback(new URLSearchParams(searchStr.startsWith("?") ? searchStr.slice(1) : searchStr), createClient()).then(
            (to) => {
                if (active) router.history.replace(to);
            },
        );
        return () => {
            active = false;
        };
    }, [router, searchStr]);
    return (
        <main className="flex min-h-dvh items-center justify-center">
            <LoadingIndicator type="line-simple" size="md" />
        </main>
    );
}

function HomeScreen() {
    return <AsyncPage queryKey={["page", "home"]} load={() => Home()} />;
}

function SetupScreen() {
    return <AsyncPage queryKey={["page", "setup"]} load={() => SetupPage()} />;
}

function InviteScreen() {
    const { token } = useParams({ strict: false }) as { token: string };
    return <AsyncPage queryKey={["page", "invite", token]} load={() => InvitePage({ params: Promise.resolve({ token }) })} />;
}

function OrgHomeScreen() {
    const { org } = useParams({ strict: false }) as { org: string };
    return <AsyncPage queryKey={["org", org, "home"]} load={() => OrgHomePage({ params: Promise.resolve({ org }) })} />;
}

function ModuleScreen() {
    const { org, module } = useParams({ strict: false }) as { org: string; module: string };
    return <AsyncPage queryKey={["org", org, module]} load={() => ModulePage({ params: Promise.resolve({ org, module }) })} />;
}

function ItemScreen() {
    const params = useParams({ strict: false }) as { org: string; module: string; _splat?: string };
    const searchStr = useRouterState({ select: (state) => state.location.searchStr });
    const slug = (params._splat ?? "").split("/").filter(Boolean);
    return (
        <AsyncPage
            queryKey={["org", params.org, params.module, slug.join("/"), searchStr]}
            load={() =>
                ItemPage({
                    params: Promise.resolve({ org: params.org, module: params.module, slug }),
                    searchParams: Promise.resolve(searchRecord(searchStr)),
                })
            }
        />
    );
}

function UsersScreen() {
    const { org } = useParams({ strict: false }) as { org: string };
    return <AsyncPage queryKey={["org", org, "users"]} load={() => UsersPage({ params: Promise.resolve({ org }) })} />;
}

function MemberScreen() {
    const { org, userId } = useParams({ strict: false }) as { org: string; userId: string };
    return <AsyncPage queryKey={["org", org, "users", userId]} load={() => MemberPage({ params: Promise.resolve({ org, userId }) })} />;
}

function RolesScreen() {
    const { org } = useParams({ strict: false }) as { org: string };
    return <AsyncPage queryKey={["org", org, "role-permissions"]} load={() => RolePermissionsPage({ params: Promise.resolve({ org }) })} />;
}

function PrintScreen() {
    const { doctype, id } = useParams({ strict: false }) as { doctype: string; id: string };
    return (
        <AsyncPage
            queryKey={["print", doctype, id]}
            load={() => PrintPage({ params: Promise.resolve({ doctype, id }), searchParams: Promise.resolve({}) })}
        />
    );
}

async function requireSession(pathname: string, searchStr: string) {
    const { data } = await createClient().auth.getSession();
    if (data.session) return;
    const next = `${pathname}${searchStr}`;
    throw redirect({ to: "/login", search: { next }, replace: true });
}

const rootRoute = createRootRoute({ component: Root, notFoundComponent: NotFound });

const indexRoute = createRoute({ getParentRoute: () => rootRoute, path: "/", component: HomeScreen });

const loginRoute = createRoute({
    getParentRoute: () => rootRoute,
    path: "/login",
    validateSearch: (search: Record<string, unknown>) => ({ next: typeof search.next === "string" ? search.next : undefined }),
    beforeLoad: async ({ search }) => {
        const { data } = await createClient().auth.getSession();
        if (data.session) throw redirect({ href: safeNext(search.next) });
    },
    component: () => (
        <AuthScreen>
            <LoginPage />
        </AuthScreen>
    ),
});

const signupRoute = createRoute({
    getParentRoute: () => rootRoute,
    path: "/signup",
    component: () => (
        <AuthScreen>
            <SignupPage />
        </AuthScreen>
    ),
});

const forgotRoute = createRoute({
    getParentRoute: () => rootRoute,
    path: "/forgot-password",
    component: () => (
        <AuthScreen>
            <ForgotPasswordPage />
        </AuthScreen>
    ),
});

const updatePasswordRoute = createRoute({
    getParentRoute: () => rootRoute,
    path: "/update-password",
    component: () => (
        <AuthScreen>
            <UpdatePasswordPage />
        </AuthScreen>
    ),
});

const callbackRoute = createRoute({ getParentRoute: () => rootRoute, path: "/auth/callback", component: CallbackScreen });

const inviteRoute = createRoute({ getParentRoute: () => rootRoute, path: "/invite/$token", component: InviteScreen });

const authedRoute = createRoute({
    getParentRoute: () => rootRoute,
    id: "authed",
    beforeLoad: ({ location }) => requireSession(location.pathname, location.searchStr),
    component: () => <Outlet />,
});

const setupRoute = createRoute({ getParentRoute: () => authedRoute, path: "/setup", component: SetupScreen });

const printRoute = createRoute({ getParentRoute: () => authedRoute, path: "/print/$doctype/$id", component: PrintScreen });

const orgRoute = createRoute({ getParentRoute: () => authedRoute, path: "/$org", component: OrgShell });

const orgIndexRoute = createRoute({ getParentRoute: () => orgRoute, path: "/", component: OrgHomeScreen });

const usersRoute = createRoute({ getParentRoute: () => orgRoute, path: "setup/users", component: UsersScreen });

const memberRoute = createRoute({ getParentRoute: () => orgRoute, path: "setup/users/$userId", component: MemberScreen });

const rolesRoute = createRoute({ getParentRoute: () => orgRoute, path: "setup/role-permissions", component: RolesScreen });

const moduleRoute = createRoute({ getParentRoute: () => orgRoute, path: "$module", component: ModuleScreen });

const itemRoute = createRoute({ getParentRoute: () => orgRoute, path: "$module/$", component: ItemScreen });

const routeTree = rootRoute.addChildren([
    indexRoute,
    loginRoute,
    signupRoute,
    forgotRoute,
    updatePasswordRoute,
    callbackRoute,
    inviteRoute,
    authedRoute.addChildren([
        setupRoute,
        printRoute,
        orgRoute.addChildren([usersRoute, memberRoute, rolesRoute, orgIndexRoute, moduleRoute, itemRoute]),
    ]),
]);

export const router = createRouter({ routeTree, defaultPreload: "intent" });

declare module "@tanstack/react-router" {
    interface Register {
        router: typeof router;
    }
}
