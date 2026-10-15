"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { Check, Plus, Trash01 } from "@untitledui/icons";
import { type FormEvent, useEffect, useMemo, useRef, useState } from "react";
import { type Control, useFieldArray, useForm, useFormState, useWatch } from "react-hook-form";
import { LoadingIndicator } from "@/components/application/loading-indicator/loading-indicator";
import { Button } from "@/components/base/buttons/button";
import { ButtonUtility } from "@/components/base/buttons/button-utility";
import type { SelectItemType } from "@/components/base/select/select";
import { FormAlert } from "@/components/erp/form-alert";
import { FormComboBox } from "@/components/erp/form-combobox";
import { FormInput } from "@/components/erp/form-input";
import { type ChartAccount, type ChartOption, chartPreview, chartsForCountry, provisionOrganization } from "@/lib/actions/organization";
import { defaultFiscalYear, fiscalYearEnd } from "@/lib/fiscal-year";
import { applyFieldErrors } from "@/lib/forms";
import { browserTimeZone, timeZoneOptions } from "@/lib/intl";
import { Redirecting } from "@/lib/navigate";
import { companyAbbr, type ProvisionOrganizationInput, provisionOrganizationSchema, slugify } from "@/lib/schemas/organization";
import { cx } from "@/utils/cx";

type Values = ProvisionOrganizationInput;

const STEPS = [
    { key: "org", label: "Organization", title: "Create your organization", help: "An organization holds your companies, users and data." },
    { key: "company", label: "Company", title: "Set up your company", help: "We'll use these to create your company and its accounts." },
    { key: "invites", label: "Invite", title: "Invite your team", help: "Optional. You can also invite people later from Setup → Users." },
] as const;

/** `setup_wizard.get_setup_stages()` labels, shown while `provision_organization` runs. */
const STAGES = ["Setting up the basics", "Creating your company", "Applying recommended settings"];

const stepOf = (field: string) =>
    Math.max(
        0,
        STEPS.findIndex((s) => field === s.key || field.startsWith(`${s.key}.`)),
    );

/** Today in the organization's time zone (`YYYY-MM-DD`). */
function todayIn(timeZone: string): string {
    try {
        return new Intl.DateTimeFormat("en-CA", { timeZone }).format(new Date());
    } catch {
        return new Date().toISOString().slice(0, 10);
    }
}

type SetupWizardProps = {
    countries: SelectItemType[];
    currencies: SelectItemType[];
    /** Standard role profiles (`role_profile_template`); each new organization gets a copy. */
    roleProfiles: SelectItemType[];
};

/**
 * Setup wizard (erpnext/public/js/setup_wizard.js): Organization → Company → Invite, one form with a Zod schema per
 * step, submitted once to `provision_organization`.
 */
export function SetupWizard({ countries, currencies, roleProfiles }: SetupWizardProps) {
    const [step, setStep] = useState(0);
    const [error, setError] = useState<string | null>(null);
    const [stage, setStage] = useState<number | null>(null);
    const edited = useRef({ slug: false, abbr: false, fy: false });
    const timeZones = useMemo(timeZoneOptions, []);

    const form = useForm<Values>({
        resolver: zodResolver(provisionOrganizationSchema),
        defaultValues: {
            org: { name: "", slug: "", country: "", default_currency: "", time_zone: "UTC" },
            company: { company_name: "", abbr: "", fy_start_date: "", fy_end_date: "", chart_of_accounts: "" },
            invites: [],
        },
    });
    const { control, setValue, getValues } = form;

    useEffect(() => {
        if (!form.getFieldState("org.time_zone").isDirty) setValue("org.time_zone", browserTimeZone());
    }, [form, setValue]);

    const orgName = useWatch({ control, name: "org.name" });
    useEffect(() => {
        if (!edited.current.slug) setValue("org.slug", slugify(orgName));
    }, [orgName, setValue]);

    const companyName = useWatch({ control, name: "company.company_name" });
    useEffect(() => {
        if (!edited.current.abbr) setValue("company.abbr", companyAbbr(companyName));
    }, [companyName, setValue]);

    const fyStart = useWatch({ control, name: "company.fy_start_date" });
    const fyEnd = fiscalYearEnd(fyStart);
    useEffect(() => {
        setValue("company.fy_end_date", fyEnd ?? "");
    }, [fyEnd, setValue]);

    /** set_fy_dates + the company name prefill, each time the Company step opens. */
    function prepareCompanyStep() {
        const { org, company } = getValues();
        if (!company.company_name) setValue("company.company_name", org.name);
        if (!edited.current.fy) {
            const fy = defaultFiscalYear(org.country, todayIn(org.time_zone));
            if (fy) setValue("company.fy_start_date", fy.start);
        }
    }

    async function next() {
        const ok = await form.trigger(STEPS[step].key);
        if (!ok) return;
        if (step === 0) prepareCompanyStep();
        setError(null);
        setStep(step + 1);
    }

    const submit = form.handleSubmit(async (values) => {
        setError(null);
        setStage(0);
        const timer = setInterval(() => setStage((s) => (s === null ? s : Math.min(s + 1, STAGES.length - 1))), 1200);
        const stop = () => {
            clearInterval(timer);
            setStage(null);
        };
        // On success the action redirects, so the progress stays up until the organization opens.
        const result = await provisionOrganization(values).catch((error: unknown) => {
            if (error instanceof Redirecting) return undefined;
            return { ok: false as const, error: "Could not reach the server. Try again.", fieldErrors: undefined };
        });
        if (result && !result.ok) {
            stop();
            setError(result.error);
            applyFieldErrors(form.setError, result.fieldErrors);
            const fields = Object.keys(result.fieldErrors ?? {});
            if (fields.length > 0) setStep(Math.min(...fields.map(stepOf)));
        }
    });

    /** Keeps a chart that fits the country, else preselects the country's default (`get_charts_for_country`). */
    function pickDefaultChart(charts: ChartOption[]) {
        const chosen = getValues("company.chart_of_accounts");
        if (charts.some((c) => c.name === chosen)) return;
        setValue("company.chart_of_accounts", (charts.find((c) => c.isDefault) ?? charts[0])?.name ?? "");
    }

    const onSubmit = (event: FormEvent<HTMLFormElement>) => {
        if (step < STEPS.length - 1) {
            event.preventDefault();
            void next();
            return;
        }
        void submit(event);
    };

    if (stage !== null) return <Provisioning stage={stage} />;

    const current = STEPS[step];
    return (
        <form onSubmit={onSubmit} noValidate className="flex flex-col gap-6">
            <StepIndicator step={step} />
            <div className="flex flex-col gap-1">
                <h1 className="text-display-xs font-semibold text-primary">{current.title}</h1>
                <p className="text-sm text-tertiary">{current.help}</p>
            </div>
            {error && <FormAlert>{error}</FormAlert>}

            {step === 0 && (
                <div className="flex flex-col gap-4">
                    <FormInput
                        control={control}
                        name="org.name"
                        label="Organization name"
                        placeholder="Acme Inc"
                        autoFocus
                        isRequired
                        size="sm"
                    />
                    <div
                        onInput={() => {
                            edited.current.slug = true;
                        }}
                    >
                        <FormInput
                            control={control}
                            name="org.slug"
                            label="URL"
                            hint="Lowercase letters, digits and dashes. Appears in every link."
                            isRequired
                            size="sm"
                        />
                    </div>
                    <FormComboBox
                        control={control}
                        name="org.country"
                        label="Country"
                        items={countries}
                        placeholder="Search countries"
                        isRequired
                    />
                    <FormComboBox
                        control={control}
                        name="org.default_currency"
                        label="Default currency"
                        items={currencies}
                        placeholder="Search currencies"
                        hint="Used for new companies; each company can still choose its own."
                        isRequired
                    />
                    <FormComboBox
                        control={control}
                        name="org.time_zone"
                        label="Time zone"
                        items={timeZones}
                        placeholder="Search time zones"
                        isRequired
                    />
                </div>
            )}

            {step === 1 && (
                <div className="flex flex-col gap-4">
                    <FormInput control={control} name="company.company_name" label="Company name" autoFocus isRequired size="sm" />
                    <div
                        onInput={() => {
                            edited.current.abbr = true;
                        }}
                    >
                        <FormInput
                            control={control}
                            name="company.abbr"
                            label="Company abbreviation"
                            hint="A short code added to account names, like Cash - AC."
                            isRequired
                            size="sm"
                        />
                    </div>
                    <div
                        onInput={() => {
                            edited.current.fy = true;
                        }}
                    >
                        <FormInput
                            control={control}
                            name="company.fy_start_date"
                            type="date"
                            label="Financial year begins on"
                            hint={fyEnd ? `Ends on ${fyEnd}.` : undefined}
                            isRequired
                            size="sm"
                        />
                    </div>
                    <ChartPicker control={control} country={getValues("org.country")} onCharts={pickDefaultChart} />
                </div>
            )}

            {step === 2 && <InviteRows control={control} roleProfiles={roleProfiles} />}

            <div className="flex items-center justify-between gap-3">
                {step > 0 ? (
                    <Button type="button" color="secondary" size="md" onPress={() => setStep(step - 1)}>
                        Back
                    </Button>
                ) : (
                    <span />
                )}
                <Button type="submit" size="md" isLoading={form.formState.isSubmitting} showTextWhileLoading>
                    {step < STEPS.length - 1 ? "Next" : "Create organization"}
                </Button>
            </div>
        </form>
    );
}

function StepIndicator({ step }: { step: number }) {
    return (
        <ol aria-label="Setup steps" className="flex items-center gap-2">
            {STEPS.map((s, i) => (
                <li key={s.key} aria-current={i === step ? "step" : undefined} className="flex flex-1 items-center gap-2">
                    <span
                        className={cx(
                            "flex size-6 shrink-0 items-center justify-center rounded-full text-xs font-semibold tabular-nums",
                            i < step && "bg-brand-solid text-white",
                            i === step && "bg-primary text-brand-secondary ring-2 ring-brand",
                            i > step && "bg-primary text-quaternary ring-1 ring-secondary",
                        )}
                    >
                        {i < step ? <Check className="size-3.5" aria-hidden="true" /> : i + 1}
                    </span>
                    <span className={cx("text-sm font-medium", i === step ? "text-primary" : "text-tertiary")}>{s.label}</span>
                    {i < STEPS.length - 1 && <span className="h-px flex-1 bg-border-secondary" aria-hidden="true" />}
                </li>
            ))}
        </ol>
    );
}

function Provisioning({ stage }: { stage: number }) {
    return (
        <div className="flex flex-col gap-6 py-4" role="status" aria-live="polite">
            <h1 className="text-display-xs font-semibold text-primary">Setting up your organization</h1>
            <ol className="flex flex-col gap-3">
                {STAGES.map((label, i) => (
                    <li key={label} className="flex items-center gap-3 text-sm">
                        {i < stage ? (
                            <Check className="size-5 text-fg-success-primary" aria-hidden="true" />
                        ) : i === stage ? (
                            <LoadingIndicator type="line-simple" size="sm" />
                        ) : (
                            <span className="size-5 rounded-full ring-1 ring-secondary" aria-hidden="true" />
                        )}
                        <span className={i <= stage ? "font-medium text-primary" : "text-tertiary"}>{label}</span>
                    </li>
                ))}
            </ol>
        </div>
    );
}

function ChartPicker({
    control,
    country,
    onCharts,
}: {
    control: Control<Values>;
    country: string;
    onCharts: (charts: ChartOption[]) => void;
}) {
    const [charts, setCharts] = useState<ChartOption[] | null>(null);
    const onChartsRef = useRef(onCharts);
    onChartsRef.current = onCharts;

    useEffect(() => {
        let live = true;
        setCharts(null);
        chartsForCountry(country).then((list) => {
            if (!live) return;
            setCharts(list);
            onChartsRef.current(list);
        });
        return () => {
            live = false;
        };
    }, [country]);

    const items = (charts ?? []).map((c) => ({ id: c.name, label: c.name }));
    const template = useWatch({ control, name: "company.chart_of_accounts" });

    return (
        <div className="flex flex-col gap-3">
            <FormComboBox
                control={control}
                name="company.chart_of_accounts"
                label="Chart of accounts"
                items={items}
                placeholder={charts ? "Search charts" : "Loading charts…"}
                hint="The standard chart for your country works for most businesses."
                isRequired
            />
            {template && <ChartPreview template={template} />}
        </div>
    );
}

function ChartPreview({ template }: { template: string }) {
    const [state, setState] = useState<{ template: string; rows: ChartAccount[] | null; error: string | null }>({
        template,
        rows: null,
        error: null,
    });

    useEffect(() => {
        let live = true;
        setState({ template, rows: null, error: null });
        chartPreview(template)
            .then((rows) => live && setState({ template, rows, error: null }))
            .catch(
                (e: unknown) =>
                    live && setState({ template, rows: null, error: e instanceof Error ? e.message : "Could not load the chart." }),
            );
        return () => {
            live = false;
        };
    }, [template]);

    return (
        <div className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-secondary">Preview</span>
            <div className="max-h-64 overflow-auto rounded-lg bg-primary py-1 ring-1 ring-secondary">
                {state.error ? (
                    <p className="px-3 py-2 text-sm text-error-primary">{state.error}</p>
                ) : state.rows === null ? (
                    <div className="flex justify-center py-6">
                        <LoadingIndicator type="line-simple" size="sm" />
                    </div>
                ) : state.rows.length === 0 ? (
                    <p className="px-3 py-2 text-sm text-tertiary">This chart has no accounts.</p>
                ) : (
                    <ul aria-label={`${template} accounts`}>
                        {state.rows.map((r) => (
                            <li
                                key={r.idx}
                                className={cx("py-0.5 pr-3 text-sm", r.isGroup ? "font-medium text-secondary" : "text-tertiary")}
                                style={{ paddingLeft: `${0.75 + r.depth}rem` }}
                            >
                                {r.account}
                            </li>
                        ))}
                    </ul>
                )}
            </div>
        </div>
    );
}

function InviteRows({ control, roleProfiles }: { control: Control<Values>; roleProfiles: SelectItemType[] }) {
    const { fields, append, remove } = useFieldArray({ control, name: "invites" });
    const invites = useFormState({ control, name: "invites" }).errors.invites;
    const errors = invites?.message ?? invites?.root?.message ?? null;

    return (
        <div className="flex flex-col gap-4">
            {fields.length === 0 && <p className="text-sm text-tertiary">No teammates added yet.</p>}
            {fields.map((field, i) => (
                <div key={field.id} className="flex items-start gap-3">
                    <div className="grid flex-1 grid-cols-1 gap-3 sm:grid-cols-2">
                        <FormInput
                            control={control}
                            name={`invites.${i}.email`}
                            label="Email"
                            type="email"
                            placeholder="name@company.com"
                            isRequired
                            size="sm"
                        />
                        <FormComboBox
                            control={control}
                            name={`invites.${i}.role_profile`}
                            label="Role profile"
                            items={roleProfiles}
                            placeholder="Select a profile"
                            isRequired
                        />
                    </div>
                    <div className="pt-6">
                        <ButtonUtility
                            size="sm"
                            color="tertiary"
                            icon={Trash01}
                            tooltip="Remove"
                            aria-label={`Remove invite ${i + 1}`}
                            onPress={() => remove(i)}
                        />
                    </div>
                </div>
            ))}
            {errors && <p className="text-sm text-error-primary">{errors}</p>}
            <div>
                <Button
                    type="button"
                    color="secondary"
                    size="sm"
                    iconLeading={Plus}
                    onPress={() => append({ email: "", role_profile: "" })}
                >
                    Add teammate
                </Button>
            </div>
        </div>
    );
}
