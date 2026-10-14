import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import { NuqsAdapter } from "nuqs/adapters/next/app";
import { RouteProvider } from "@/providers/router-provider";
import { Theme } from "@/providers/theme";
import "@/styles/globals.css";
import { cx } from "@/utils/cx";

const inter = Inter({
    subsets: ["latin"],
    display: "swap",
    variable: "--font-inter",
});

export const metadata: Metadata = {
    title: { default: "headless-erp", template: "%s · headless-erp" },
    description: "Multi-tenant ERP",
};

export const viewport: Viewport = {
    colorScheme: "light dark",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
    return (
        <html lang="en" suppressHydrationWarning>
            <body className={cx(inter.variable, "bg-primary antialiased")}>
                <NuqsAdapter>
                    <RouteProvider>
                        <Theme>{children}</Theme>
                    </RouteProvider>
                </NuqsAdapter>
            </body>
        </html>
    );
}
