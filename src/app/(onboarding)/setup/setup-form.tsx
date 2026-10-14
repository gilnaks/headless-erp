"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useEffect, useMemo, useRef, useState } from "react";
import { useForm } from "react-hook-form";
import { Button } from "@/components/base/buttons/button";
import { FormAlert } from "@/components/erp/form-alert";
import { FormComboBox } from "@/components/erp/form-combobox";
import { FormInput } from "@/components/erp/form-input";
import { createOrganization } from "@/lib/actions/organization";
import { applyFieldErrors } from "@/lib/forms";
import { browserTimeZone, currencyOptions, timeZoneOptions } from "@/lib/intl";
import { type CreateOrganizationInput, createOrganizationSchema, slugify } from "@/lib/schemas/organization";
import { countries } from "@/utils/countries";

const countryOptions = countries.map((c) => ({ id: c.name, label: c.name }));

export function SetupForm() {
    const [error, setError] = useState<string | null>(null);
    const slugEdited = useRef(false);
    const currencies = useMemo(currencyOptions, []);
    const timeZones = useMemo(timeZoneOptions, []);

    const form = useForm<CreateOrganizationInput>({
        resolver: zodResolver(createOrganizationSchema),
        defaultValues: { name: "", slug: "", country: "", default_currency: "", time_zone: "UTC" },
    });

    useEffect(() => {
        if (!form.getFieldState("time_zone").isDirty) form.setValue("time_zone", browserTimeZone());
    }, [form]);

    const name = form.watch("name");
    useEffect(() => {
        if (!slugEdited.current) form.setValue("slug", slugify(name));
    }, [name, form]);

    const onSubmit = form.handleSubmit(async (values) => {
        setError(null);
        const result = await createOrganization(values);
        if (result && !result.ok) {
            setError(result.error);
            applyFieldErrors(form.setError, result.fieldErrors);
        }
    });

    return (
        <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
            {error && <FormAlert>{error}</FormAlert>}
            <FormInput control={form.control} name="name" label="Organization name" placeholder="Acme Inc" autoFocus isRequired size="sm" />
            <div
                onInput={() => {
                    slugEdited.current = true;
                }}
            >
                <FormInput
                    control={form.control}
                    name="slug"
                    label="URL"
                    hint="Lowercase letters, digits and dashes. Appears in every link."
                    isRequired
                    size="sm"
                />
            </div>
            <FormComboBox
                control={form.control}
                name="country"
                label="Country"
                items={countryOptions}
                placeholder="Search countries"
                isRequired
            />
            <FormComboBox
                control={form.control}
                name="default_currency"
                label="Default currency"
                items={currencies}
                placeholder="Search currencies"
                hint="Used for new companies; each company can still choose its own."
                isRequired
            />
            <FormComboBox
                control={form.control}
                name="time_zone"
                label="Time zone"
                items={timeZones}
                placeholder="Search time zones"
                isRequired
            />
            <Button type="submit" size="md" isLoading={form.formState.isSubmitting} showTextWhileLoading>
                Create organization
            </Button>
        </form>
    );
}
