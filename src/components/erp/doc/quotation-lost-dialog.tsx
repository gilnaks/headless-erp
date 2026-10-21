import { useEffect, useState } from "react";
import { Heading as AriaHeading, type Key } from "react-aria-components";
import { createRoot } from "react-dom/client";
import { Dialog, Modal, ModalOverlay } from "@/components/application/modals/modal";
import { Button } from "@/components/base/buttons/button";
import { Select } from "@/components/base/select/select";
import { TextArea } from "@/components/base/textarea/textarea";
import { FormAlert } from "@/components/erp/form-alert";
import { dbError } from "@/lib/errors";
import { createClient } from "@/lib/supabase/client";

export type QuotationLostChoice = { reasonId: string; detail: string };

type Reason = { id: string; label: string };

/** Asks for a Quotation Lost Reason and an optional detail. Cancel resolves to null. */
export function promptQuotationLost(): Promise<QuotationLostChoice | null> {
    return new Promise((resolve) => {
        const host = document.createElement("div");
        document.body.appendChild(host);
        const root = createRoot(host);
        let settled = false;
        const finish = (value: QuotationLostChoice | null) => {
            if (settled) return;
            settled = true;
            root.unmount();
            host.remove();
            resolve(value);
        };
        root.render(<QuotationLostDialog onDone={finish} />);
    });
}

function QuotationLostDialog({ onDone }: { onDone: (value: QuotationLostChoice | null) => void }) {
    const [open, setOpen] = useState(true);
    return (
        <ModalOverlay
            isOpen={open}
            isDismissable
            onOpenChange={(next) => {
                setOpen(next);
                if (!next) onDone(null);
            }}
        >
            <Modal className="max-w-lg">
                <Dialog aria-label="Set as Lost">{open && <LostForm onDone={onDone} />}</Dialog>
            </Modal>
        </ModalOverlay>
    );
}

function LostForm({ onDone }: { onDone: (value: QuotationLostChoice | null) => void }) {
    const [reasons, setReasons] = useState<Reason[]>([]);
    const [reasonId, setReasonId] = useState<string | null>(null);
    const [detail, setDetail] = useState("");
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        let live = true;
        void (async () => {
            const { data, error: queryError } = await createClient()
                .from("quotation_lost_reason")
                .select("id, order_lost_reason")
                .order("order_lost_reason");
            if (!live) return;
            if (queryError) setError(dbError(queryError).message);
            else setReasons((data ?? []).map((row) => ({ id: row.id, label: row.order_lost_reason })));
            setLoading(false);
        })();
        return () => {
            live = false;
        };
    }, []);

    const confirm = () => {
        if (!reasonId) {
            setError("Quotation Lost Reason is required.");
            return;
        }
        onDone({ reasonId, detail: detail.trim() });
    };

    return (
        <form
            noValidate
            className="flex flex-col gap-4 p-6"
            onSubmit={(event) => {
                event.preventDefault();
                confirm();
            }}
        >
            <AriaHeading slot="title" className="text-lg font-semibold text-primary">
                Set as Lost
            </AriaHeading>
            {error && <FormAlert>{error}</FormAlert>}
            <Select
                label="Quotation Lost Reason"
                placeholder="Select a reason"
                items={reasons}
                size="sm"
                isRequired
                isDisabled={loading || reasons.length === 0}
                selectedKey={reasonId}
                onSelectionChange={(key: Key | null) => setReasonId(key == null ? null : String(key))}
                hint={reasons.length === 0 && !loading ? "Add a Quotation Lost Reason first." : undefined}
            >
                {(item) => <Select.Item id={item.id} label={item.label} />}
            </Select>
            <TextArea label="Detail" size="sm" rows={3} value={detail} onChange={setDetail} />
            <div className="flex justify-end gap-2">
                <Button size="sm" color="secondary" onPress={() => onDone(null)}>
                    Cancel
                </Button>
                <Button size="sm" type="submit" isDisabled={loading || reasons.length === 0}>
                    Set as Lost
                </Button>
            </div>
        </form>
    );
}
