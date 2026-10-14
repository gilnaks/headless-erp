import { z } from "zod";

/** Mirrors `[auth] minimum_password_length` in supabase/config.toml. */
export const MIN_PASSWORD_LENGTH = 8;

const email = z.string().trim().toLowerCase().pipe(z.email("Enter a valid email address"));
const newPassword = z
    .string()
    .min(MIN_PASSWORD_LENGTH, `Use at least ${MIN_PASSWORD_LENGTH} characters`)
    .max(72, "Use at most 72 characters");

export const passwordLoginSchema = z.object({
    email,
    password: z.string().min(1, "Enter your password"),
    next: z.string().optional(),
});

export const magicLinkSchema = z.object({
    email,
    next: z.string().optional(),
});

export const signupSchema = z.object({
    first_name: z.string().trim().min(1, "Enter your first name").max(100),
    last_name: z.string().trim().max(100),
    email,
    password: newPassword,
    next: z.string().optional(),
});

export const forgotPasswordSchema = z.object({ email });

export const updatePasswordSchema = z
    .object({
        password: newPassword,
        confirm: z.string(),
    })
    .refine((v) => v.password === v.confirm, { path: ["confirm"], message: "Passwords do not match" });

export type PasswordLoginInput = z.input<typeof passwordLoginSchema>;
export type MagicLinkInput = z.input<typeof magicLinkSchema>;
export type SignupInput = z.input<typeof signupSchema>;
export type ForgotPasswordInput = z.input<typeof forgotPasswordSchema>;
export type UpdatePasswordInput = z.input<typeof updatePasswordSchema>;
