"use client";

import type { ReactNode } from "react";
import { Button } from "@/components/base/buttons/button";
import { signOut } from "@/lib/auth/sign-out";

export function SignOutButton({
    children,
    className,
    color = "secondary",
}: {
    children: ReactNode;
    className?: string;
    color?: "secondary" | "tertiary";
}) {
    return (
        <Button type="button" size="md" color={color} className={className} onClick={() => void signOut()}>
            {children}
        </Button>
    );
}
