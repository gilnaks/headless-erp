"use client";

import type { PropsWithChildren } from "react";
import { useRouter } from "@/lib/next-nav";
import { RouterProvider } from "react-aria-components";

declare module "react-aria-components" {
    interface RouterConfig {
        routerOptions: undefined;
    }
}

export const RouteProvider = ({ children }: PropsWithChildren) => {
    const router = useRouter();

    return <RouterProvider navigate={router.push}>{children}</RouterProvider>;
};
