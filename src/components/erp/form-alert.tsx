import type { ReactNode } from "react";
import { cx } from "@/utils/cx";

type FormAlertProps = {
    tone?: "error" | "success" | "info";
    children: ReactNode;
    className?: string;
};

const TONES = {
    error: "bg-error-primary text-error-primary",
    success: "bg-success-primary text-success-primary",
    info: "bg-secondary text-secondary",
};

export function FormAlert({ tone = "error", children, className }: FormAlertProps) {
    return (
        <div role={tone === "error" ? "alert" : "status"} className={cx("rounded-lg px-3 py-2.5 text-sm", TONES[tone], className)}>
            {children}
        </div>
    );
}
