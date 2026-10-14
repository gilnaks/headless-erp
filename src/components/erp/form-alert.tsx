import type { ReactNode } from "react";
import { cx } from "@/utils/cx";

type FormAlertProps = {
    tone?: "error" | "success";
    children: ReactNode;
    className?: string;
};

export function FormAlert({ tone = "error", children, className }: FormAlertProps) {
    return (
        <div
            role={tone === "error" ? "alert" : "status"}
            className={cx(
                "rounded-lg px-3 py-2.5 text-sm",
                tone === "error" ? "bg-error-primary text-error-primary" : "bg-success-primary text-success-primary",
                className,
            )}
        >
            {children}
        </div>
    );
}
