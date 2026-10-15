"use client";

import { ChevronLeft, Printer } from "@untitledui/icons";
import type { Key } from "react-aria-components";
import { Button } from "@/components/base/buttons/button";
import { Select } from "@/components/base/select/select";
import { useRouter } from "@/lib/next-nav";

type PrintToolbarProps = {
    title: string;
    backHref: string;
    formats: { id: string; label: string }[];
    formatId: string | null;
    canPrint: boolean;
};

/** Screen-only bar above the page: back to the form, Print Format picker (`?format=`), Print (`window.print`). */
export function PrintToolbar({ title, backHref, formats, formatId, canPrint }: PrintToolbarProps) {
    const router = useRouter();
    return (
        <header className="sticky top-0 z-10 flex flex-wrap items-center gap-3 border-b border-secondary bg-primary px-4 py-2 print:hidden">
            <Button href={backHref} size="sm" color="tertiary" iconLeading={ChevronLeft}>
                {title}
            </Button>
            <div className="ml-auto flex items-center gap-2">
                {formats.length > 0 && (
                    <Select
                        aria-label="Print Format"
                        size="sm"
                        className="w-60"
                        items={formats}
                        selectedKey={formatId}
                        onSelectionChange={(key: Key | null) => key && router.replace(`?format=${encodeURIComponent(String(key))}`)}
                    >
                        {(item) => <Select.Item id={item.id} label={item.label} />}
                    </Select>
                )}
                <Button size="sm" iconLeading={Printer} onPress={() => window.print()} isDisabled={!canPrint}>
                    Print
                </Button>
            </div>
        </header>
    );
}
