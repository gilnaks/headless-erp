import { AccountsDashboard } from "@/components/erp/dashboard/accounts-dashboard";
import { StockDashboard } from "@/components/erp/dashboard/stock-dashboard";
import { DocForm } from "@/components/erp/doc/doc-form";
import { DocList } from "@/components/erp/doc/doc-list";
import { TreeView } from "@/components/erp/doc/tree-view";
import { NotPermitted } from "@/components/erp/not-permitted";
import { PlaceholderPage } from "@/components/erp/placeholder-page";
import { BalanceSheet } from "@/components/erp/report/balance-sheet";
import { CashFlow } from "@/components/erp/report/cash-flow";
import { GeneralLedger } from "@/components/erp/report/general-ledger";
import { ProfitAndLoss } from "@/components/erp/report/profit-and-loss";
import { StockBalance } from "@/components/erp/report/stock-balance";
import { StockLedger } from "@/components/erp/report/stock-ledger";
import { type FiscalYearChoice, TrialBalance } from "@/components/erp/report/trial-balance";
import { TrialBalanceForParty } from "@/components/erp/report/trial-balance-for-party";
import { findLinkForPath, getModule, type NavLink } from "@/config/navigation";
import type { Doctype } from "@/doctypes/define";
import { getDoctype } from "@/doctypes/registry";
import { prefillValues } from "@/doctypes/schema";
import { loadListParams, loadViewParams } from "@/lib/list-params";
import { notFound } from "@/lib/navigate";
import { loadBankBalance, loadCardSum, loadChartTimeseries } from "@/lib/queries/accounts-dashboard";
import { loadBalanceSheet } from "@/lib/queries/balance-sheet";
import { loadCashFlow } from "@/lib/queries/cash-flow";
import { getDoc, getDocPermissions, getOrgBySlug, getSingleDoc, listDocs, listTreeNodes } from "@/lib/queries/doc";
import { loadGeneralLedger } from "@/lib/queries/general-ledger";
import { getListLinkTitles } from "@/lib/queries/links";
import { loadProfitAndLoss } from "@/lib/queries/profit-and-loss";
import { getReferenceOptions } from "@/lib/queries/reference";
import { loadStockBalance } from "@/lib/queries/stock-balance";
import { loadStockDashboard } from "@/lib/queries/stock-dashboard";
import { loadStockLedger } from "@/lib/queries/stock-ledger";
import { loadTrialBalance } from "@/lib/queries/trial-balance";
import { loadTrialBalanceForParty } from "@/lib/queries/trial-balance-for-party";
import { optionSourcesOf } from "@/lib/reference-options";
import { createClient } from "@/lib/supabase/client";

type ItemPageProps = {
    params: Promise<{ org: string; module: string; slug: string[] }>;
    searchParams: Promise<Record<string, string | string[] | undefined>>;
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function describe(link: NavLink, path: string): string {
    switch (link.target.kind) {
        case "doctype":
            return path === link.path
                ? `The ${link.target.doctype} list (filters, bulk actions, "+ New") is not built yet.`
                : `The ${link.target.doctype} form is not built yet.`;
        case "report":
            return `The ${link.target.report} report is not built yet.`;
        case "dashboard":
            return "Number cards and charts for this module are not built yet.";
        default:
            return "This page is not built yet.";
    }
}

async function ListRoute({ d, orgSlug, searchParams }: { d: Doctype; orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, d.doctype);
    if (!perms.read) return <NotPermitted action="view" doctype={d.doctype} />;

    if (d.tree && (await loadViewParams(searchParams)).view === "tree") {
        const rows = await listTreeNodes(d, org.id);
        const titles = await getListLinkTitles(d, org.id, rows, d.tree.filters ?? []);
        return <TreeView doctype={d.doctype} orgSlug={org.slug} rows={rows} titles={titles} canCreate={perms.create} />;
    }

    const { q, sort, desc, page, size } = await loadListParams(searchParams);
    const list = await listDocs(d, org.id, { q, sort: sort ?? undefined, desc, page, pageSize: size });
    const titles = await getListLinkTitles(d, org.id, list.rows);
    return <DocList doctype={d.doctype} orgSlug={org.slug} {...list} titles={titles} canCreate={perms.create} />;
}

type FormRouteProps = { d: Doctype; orgSlug: string; id: string | null; searchParams?: ItemPageProps["searchParams"] };

async function FormRoute({ d, orgSlug, id, searchParams }: FormRouteProps) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, d.doctype);

    if (id === null) {
        if (!perms.create) return <NotPermitted action="create" doctype={d.doctype} />;
        const [referenceOptions, prefill] = await Promise.all([
            getReferenceOptions(optionSourcesOf(d), org.id),
            searchParams ? searchParams.then((sp) => prefillValues(d, sp)) : null,
        ]);
        return (
            <DocForm
                doctype={d.doctype}
                orgSlug={org.slug}
                id={null}
                row={prefill}
                canSave
                canDelete={false}
                canSubmit={perms.submit}
                canCancel={perms.cancel}
                canAmend={perms.amend}
                referenceOptions={referenceOptions}
            />
        );
    }

    const [row, referenceOptions] = await Promise.all([getDoc(d, org.id, id), getReferenceOptions(optionSourcesOf(d), org.id)]);
    if (!row) notFound();
    return (
        <DocForm
            doctype={d.doctype}
            orgSlug={org.slug}
            id={id}
            row={row}
            canSave={perms.write}
            canDelete={perms.delete}
            canSubmit={perms.submit}
            canCancel={perms.cancel}
            canAmend={perms.amend}
            referenceOptions={referenceOptions}
        />
    );
}

async function SingleRoute({ d, orgSlug }: { d: Doctype; orgSlug: string }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const perms = await getDocPermissions(org.id, d.doctype);
    if (!perms.read) return <NotPermitted action="view" doctype={d.doctype} />;

    const [row, referenceOptions] = await Promise.all([getSingleDoc(d, org.id), getReferenceOptions(optionSourcesOf(d), org.id)]);
    if (!row) notFound();
    return (
        <DocForm
            doctype={d.doctype}
            orgSlug={org.slug}
            id={String(row.id)}
            row={row}
            canSave={perms.write}
            canDelete={false}
            canSubmit={perms.submit}
            canCancel={perms.cancel}
            canAmend={perms.amend}
            referenceOptions={referenceOptions}
        />
    );
}

function isoDate(date: Date): string {
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${date.getFullYear()}-${month}-${day}`;
}

function defaultRange(): { from: string; to: string } {
    const to = new Date();
    const from = new Date();
    from.setMonth(from.getMonth() - 1);
    return { from: isoDate(from), to: isoDate(to) };
}

async function StockLedgerRoute({ orgSlug, searchParams }: { orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const params = await searchParams;
    const one = (key: string) => {
        const value = params[key];
        return Array.isArray(value) ? value[0] : value;
    };
    const range = defaultRange();
    const from = one("from") || range.from;
    const to = one("to") || range.to;
    const item = one("item") ?? "";
    const warehouse = one("warehouse") ?? "";
    const voucherType = one("voucher_type") ?? "";
    let company = one("company") ?? "";
    if (!company) {
        const supabase = createClient();
        const { data } = await supabase.from("companies").select("id").eq("org_id", org.id).limit(2);
        if (data?.length === 1) company = data[0].id;
    }
    const report = company
        ? await loadStockLedger({ company, from, to, item, warehouse, voucherType })
        : { columns: [], rows: [], error: "Company is mandatory" };

    return (
        <StockLedger
            orgSlug={org.slug}
            companyId={company}
            from={from}
            to={to}
            itemId={item}
            warehouseId={warehouse}
            voucherType={voucherType}
            columns={report.columns}
            rows={report.rows}
            error={report.error}
        />
    );
}

async function StockBalanceRoute({ orgSlug, searchParams }: { orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const params = await searchParams;
    const one = (key: string) => {
        const value = params[key];
        return Array.isArray(value) ? value[0] : value;
    };
    const range = defaultRange();
    const from = one("from") || range.from;
    const to = one("to") || range.to;
    const item = one("item") ?? "";
    const itemGroup = one("item_group") ?? "";
    const warehouse = one("warehouse") ?? "";
    const includeZero = one("zero") === "true";
    let company = one("company") ?? "";
    if (!company) {
        const supabase = createClient();
        const { data } = await supabase.from("companies").select("id").eq("org_id", org.id).limit(2);
        if (data?.length === 1) company = data[0].id;
    }
    const report = company
        ? await loadStockBalance({ company, from, to, item, itemGroup, warehouse, includeZero })
        : { columns: [], rows: [], error: "Company is mandatory" };

    return (
        <StockBalance
            orgSlug={org.slug}
            companyId={company}
            from={from}
            to={to}
            itemId={item}
            itemGroupId={itemGroup}
            warehouseId={warehouse}
            includeZero={includeZero}
            columns={report.columns}
            rows={report.rows}
            error={report.error}
        />
    );
}

async function GeneralLedgerRoute({ orgSlug, searchParams }: { orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const params = await searchParams;
    const one = (key: string) => {
        const value = params[key];
        return Array.isArray(value) ? value[0] : value;
    };
    const range = defaultRange();
    const from = one("from") || range.from;
    const to = one("to") || range.to;
    const account = one("account") ?? "";
    const showOpening = one("opening") === "true";
    let company = one("company") ?? "";
    if (!company) {
        const supabase = createClient();
        const { data } = await supabase.from("companies").select("id").eq("org_id", org.id).limit(2);
        if (data?.length === 1) company = data[0].id;
    }
    const report = company
        ? await loadGeneralLedger({ company, from, to, account, showOpening })
        : { columns: [], rows: [], error: "Company is mandatory" };

    return (
        <GeneralLedger
            orgSlug={org.slug}
            companyId={company}
            from={from}
            to={to}
            accountId={account}
            showOpening={showOpening}
            columns={report.columns}
            rows={report.rows}
            error={report.error}
        />
    );
}

async function TrialBalanceRoute({ orgSlug, searchParams }: { orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const params = await searchParams;
    const one = (key: string) => {
        const value = params[key];
        return Array.isArray(value) ? value[0] : value;
    };
    const supabase = createClient();
    const { data } = await supabase
        .from("fiscal_year")
        .select("id, year, year_start_date, year_end_date")
        .eq("org_id", org.id)
        .order("year_start_date", { ascending: false });
    const years: FiscalYearChoice[] = (data ?? []).map((year) => ({
        id: year.id,
        label: year.year,
        start: year.year_start_date,
        end: year.year_end_date,
    }));
    const today = isoDate(new Date());
    const current = years.find((year) => year.start <= today && year.end >= today) ?? years[0];
    const requested = one("fiscal_year");
    const selected = years.find((year) => year.id === requested) ?? current;
    const from = one("from") || selected?.start || today;
    const to = one("to") || selected?.end || today;
    const showZero = one("zero") === "true";
    const showGroups = one("groups") !== "false";
    const showNet = one("net") !== "false";
    let company = one("company") ?? "";
    if (!company) {
        const { data: companies } = await supabase.from("companies").select("id").eq("org_id", org.id).limit(2);
        if (companies?.length === 1) company = companies[0].id;
    }
    const report =
        company && selected
            ? await loadTrialBalance({
                  company,
                  fiscalYear: selected.id,
                  from,
                  to,
                  showZero,
                  showGroups,
                  showNet,
              })
            : { columns: [], rows: [], warnings: [], error: company ? "Fiscal Year is required" : "Company is mandatory" };

    return (
        <TrialBalance
            orgSlug={org.slug}
            companyId={company}
            fiscalYearId={selected?.id ?? ""}
            years={years}
            from={from}
            to={to}
            showZero={showZero}
            showGroups={showGroups}
            showNet={showNet}
            columns={report.columns}
            rows={report.rows}
            warnings={report.warnings}
            error={report.error}
        />
    );
}

async function TrialBalanceForPartyRoute({ orgSlug, searchParams }: { orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const params = await searchParams;
    const one = (key: string) => {
        const value = params[key];
        return Array.isArray(value) ? value[0] : value;
    };
    const supabase = createClient();
    const { data } = await supabase
        .from("fiscal_year")
        .select("id, year, year_start_date, year_end_date")
        .eq("org_id", org.id)
        .order("year_start_date", { ascending: false });
    const years: FiscalYearChoice[] = (data ?? []).map((year) => ({
        id: year.id,
        label: year.year,
        start: year.year_start_date,
        end: year.year_end_date,
    }));
    const today = isoDate(new Date());
    const current = years.find((year) => year.start <= today && year.end >= today) ?? years[0];
    const requested = one("fiscal_year");
    const selected = years.find((year) => year.id === requested) ?? current;
    const from = one("from") || selected?.start || today;
    const to = one("to") || selected?.end || today;
    const partyType = one("party_type") === "Supplier" ? "Supplier" : "Customer";
    const party = one("party") ?? "";
    const showZero = one("zero") === "true";
    const excludeZero = one("exclude") !== "false";
    let company = one("company") ?? "";
    if (!company) {
        const { data: companies } = await supabase.from("companies").select("id").eq("org_id", org.id).limit(2);
        if (companies?.length === 1) company = companies[0].id;
    }
    const report =
        company && selected
            ? await loadTrialBalanceForParty({
                  company,
                  fiscalYear: selected.id,
                  from,
                  to,
                  partyType,
                  party,
                  showZero,
                  excludeZero,
              })
            : { columns: [], rows: [], warnings: [], error: company ? "Fiscal Year is required" : "Company is mandatory" };

    return (
        <TrialBalanceForParty
            orgSlug={org.slug}
            companyId={company}
            fiscalYearId={selected?.id ?? ""}
            years={years}
            from={from}
            to={to}
            partyType={partyType}
            partyId={party}
            showZero={showZero}
            excludeZero={excludeZero}
            columns={report.columns}
            rows={report.rows}
            warnings={report.warnings}
            error={report.error}
        />
    );
}

async function ProfitAndLossRoute({ orgSlug, searchParams }: { orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const params = await searchParams;
    const one = (key: string) => {
        const value = params[key];
        return Array.isArray(value) ? value[0] : value;
    };
    const supabase = createClient();
    const { data } = await supabase
        .from("fiscal_year")
        .select("id, year, year_start_date, year_end_date")
        .eq("org_id", org.id)
        .order("year_start_date", { ascending: false });
    const years: FiscalYearChoice[] = (data ?? []).map((year) => ({
        id: year.id,
        label: year.year,
        start: year.year_start_date,
        end: year.year_end_date,
    }));
    const today = isoDate(new Date());
    const current = years.find((year) => year.start <= today && year.end >= today) ?? years[0];
    const fromYear = years.find((year) => year.id === one("from_fy")) ?? current;
    const toYear = years.find((year) => year.id === one("to_fy")) ?? current;
    const basis = one("basis") === "Date Range" ? "Date Range" : "Fiscal Year";
    const requestedPeriod = one("periodicity");
    const periodicity =
        requestedPeriod === "Monthly" || requestedPeriod === "Quarterly" || requestedPeriod === "Half-Yearly" ? requestedPeriod : "Yearly";
    const from = one("from") || fromYear?.start || today;
    const to = one("to") || toYear?.end || today;
    const accumulated = one("accumulated") === "true";
    const showZero = one("zero") === "true";
    let company = one("company") ?? "";
    if (!company) {
        const { data: companies } = await supabase.from("companies").select("id").eq("org_id", org.id).limit(2);
        if (companies?.length === 1) company = companies[0].id;
    }
    const report =
        company && fromYear && toYear
            ? await loadProfitAndLoss({
                  company,
                  basis,
                  fromFiscalYear: fromYear.id,
                  toFiscalYear: toYear.id,
                  from,
                  to,
                  periodicity,
                  accumulated,
                  showZero,
              })
            : {
                  columns: [],
                  rows: [],
                  summary: [],
                  chart: { type: "bar" as const, labels: [], datasets: [] },
                  error: company ? "Start Year and End Year are mandatory" : "Company is mandatory",
              };

    return (
        <ProfitAndLoss
            orgSlug={org.slug}
            companyId={company}
            basis={basis}
            fromFiscalYearId={fromYear?.id ?? ""}
            toFiscalYearId={toYear?.id ?? ""}
            years={years}
            from={from}
            to={to}
            periodicity={periodicity}
            accumulated={accumulated}
            showZero={showZero}
            columns={report.columns}
            rows={report.rows}
            summary={report.summary}
            chart={report.chart}
            error={report.error}
        />
    );
}

async function BalanceSheetRoute({ orgSlug, searchParams }: { orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const params = await searchParams;
    const one = (key: string) => {
        const value = params[key];
        return Array.isArray(value) ? value[0] : value;
    };
    const supabase = createClient();
    const { data } = await supabase
        .from("fiscal_year")
        .select("id, year, year_start_date, year_end_date")
        .eq("org_id", org.id)
        .order("year_start_date", { ascending: false });
    const years: FiscalYearChoice[] = (data ?? []).map((year) => ({
        id: year.id,
        label: year.year,
        start: year.year_start_date,
        end: year.year_end_date,
    }));
    const today = isoDate(new Date());
    const current = years.find((year) => year.start <= today && year.end >= today) ?? years[0];
    const fromYear = years.find((year) => year.id === one("from_fy")) ?? current;
    const toYear = years.find((year) => year.id === one("to_fy")) ?? current;
    const basis = one("basis") === "Date Range" ? "Date Range" : "Fiscal Year";
    const requestedPeriod = one("periodicity");
    const periodicity =
        requestedPeriod === "Monthly" || requestedPeriod === "Quarterly" || requestedPeriod === "Half-Yearly" ? requestedPeriod : "Yearly";
    const from = one("from") || fromYear?.start || today;
    const to = one("to") || toYear?.end || today;
    const accumulated = one("accumulated") !== "false";
    const showZero = one("zero") === "true";
    let company = one("company") ?? "";
    if (!company) {
        const { data: companies } = await supabase.from("companies").select("id").eq("org_id", org.id).limit(2);
        if (companies?.length === 1) company = companies[0].id;
    }
    const report =
        company && fromYear && toYear
            ? await loadBalanceSheet({
                  company,
                  basis,
                  fromFiscalYear: fromYear.id,
                  toFiscalYear: toYear.id,
                  from,
                  to,
                  periodicity,
                  accumulated,
                  showZero,
              })
            : {
                  columns: [],
                  rows: [],
                  summary: [],
                  chart: { type: "line" as const, labels: [], datasets: [] },
                  warnings: [],
                  error: company ? "Start Year and End Year are mandatory" : "Company is mandatory",
              };

    return (
        <BalanceSheet
            orgSlug={org.slug}
            companyId={company}
            basis={basis}
            fromFiscalYearId={fromYear?.id ?? ""}
            toFiscalYearId={toYear?.id ?? ""}
            years={years}
            from={from}
            to={to}
            periodicity={periodicity}
            accumulated={accumulated}
            showZero={showZero}
            columns={report.columns}
            rows={report.rows}
            summary={report.summary}
            chart={report.chart}
            warnings={report.warnings}
            error={report.error}
        />
    );
}

async function CashFlowRoute({ orgSlug, searchParams }: { orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const params = await searchParams;
    const one = (key: string) => {
        const value = params[key];
        return Array.isArray(value) ? value[0] : value;
    };
    const supabase = createClient();
    const { data } = await supabase
        .from("fiscal_year")
        .select("id, year, year_start_date, year_end_date")
        .eq("org_id", org.id)
        .order("year_start_date", { ascending: false });
    const years: FiscalYearChoice[] = (data ?? []).map((year) => ({
        id: year.id,
        label: year.year,
        start: year.year_start_date,
        end: year.year_end_date,
    }));
    const today = isoDate(new Date());
    const current = years.find((year) => year.start <= today && year.end >= today) ?? years[0];
    const fromYear = years.find((year) => year.id === one("from_fy")) ?? current;
    const toYear = years.find((year) => year.id === one("to_fy")) ?? current;
    const basis = one("basis") === "Date Range" ? "Date Range" : "Fiscal Year";
    const requestedPeriod = one("periodicity");
    const periodicity =
        requestedPeriod === "Monthly" || requestedPeriod === "Quarterly" || requestedPeriod === "Half-Yearly" ? requestedPeriod : "Yearly";
    const from = one("from") || fromYear?.start || today;
    const to = one("to") || toYear?.end || today;
    const accumulated = one("accumulated") !== "false";
    const opening = one("opening") === "true";
    let company = one("company") ?? "";
    if (!company) {
        const { data: companies } = await supabase.from("companies").select("id").eq("org_id", org.id).limit(2);
        if (companies?.length === 1) company = companies[0].id;
    }
    const report =
        company && fromYear && toYear
            ? await loadCashFlow({
                  company,
                  basis,
                  fromFiscalYear: fromYear.id,
                  toFiscalYear: toYear.id,
                  from,
                  to,
                  periodicity,
                  accumulated,
                  opening,
              })
            : {
                  columns: [],
                  rows: [],
                  summary: [],
                  chart: { type: "bar" as const, labels: [], datasets: [] },
                  error: company ? "Start Year and End Year are mandatory" : "Company is mandatory",
              };

    return (
        <CashFlow
            orgSlug={org.slug}
            companyId={company}
            basis={basis}
            fromFiscalYearId={fromYear?.id ?? ""}
            toFiscalYearId={toYear?.id ?? ""}
            years={years}
            from={from}
            to={to}
            periodicity={periodicity}
            accumulated={accumulated}
            opening={opening}
            columns={report.columns}
            rows={report.rows}
            summary={report.summary}
            chart={report.chart}
            error={report.error}
        />
    );
}

const UNAVAILABLE_CARD = { available: false };
const EMPTY_SERIES = { available: false, chart: { type: "bar" as const, labels: [], datasets: [] } };
const EMPTY_PROFIT = { type: "bar" as const, labels: [], datasets: [] };

const EMPTY_STOCK_CARD = { available: false };
const EMPTY_STOCK_SERIES = { available: false, chart: { type: "bar" as const, labels: [], datasets: [] } };

async function StockDashboardRoute({ orgSlug, searchParams }: { orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const params = await searchParams;
    const companyParam = params.company;
    let company = (Array.isArray(companyParam) ? companyParam[0] : companyParam) ?? "";
    if (!company) {
        const supabase = createClient();
        const { data: companies } = await supabase.from("companies").select("id").eq("org_id", org.id).limit(2);
        if (companies?.length === 1) company = companies[0].id;
    }
    const dashboard = company ? await loadStockDashboard({ company }) : null;

    return (
        <StockDashboard
            orgSlug={org.slug}
            companyId={company}
            items={dashboard?.items ?? EMPTY_STOCK_CARD}
            warehouses={dashboard?.warehouses ?? EMPTY_STOCK_CARD}
            stockValue={dashboard?.stockValue ?? EMPTY_STOCK_CARD}
            warehouseChart={dashboard?.warehouseChart ?? EMPTY_STOCK_SERIES}
            receipts={dashboard?.receipts ?? EMPTY_STOCK_SERIES}
            deliveries={dashboard?.deliveries ?? EMPTY_STOCK_SERIES}
            oldest={dashboard?.oldest ?? EMPTY_STOCK_SERIES}
            shortage={dashboard?.shortage ?? EMPTY_STOCK_SERIES}
            error={company ? undefined : "Company is mandatory"}
        />
    );
}

async function AccountsDashboardRoute({ orgSlug, searchParams }: { orgSlug: string; searchParams: ItemPageProps["searchParams"] }) {
    const org = await getOrgBySlug(orgSlug);
    if (!org) notFound();
    const params = await searchParams;
    const one = (key: string) => {
        const value = params[key];
        return Array.isArray(value) ? value[0] : value;
    };
    const supabase = createClient();
    const { data } = await supabase
        .from("fiscal_year")
        .select("id, year_start_date, year_end_date")
        .eq("org_id", org.id)
        .order("year_start_date", { ascending: false });
    const years = data ?? [];
    const today = isoDate(new Date());
    const current = years.find((year) => year.year_start_date <= today && year.year_end_date >= today) ?? years[0];
    const from = one("from") || current?.year_start_date || today;
    const to = one("to") || current?.year_end_date || today;
    const chartYear = years.find((year) => year.year_start_date <= to && year.year_end_date >= to) ?? current;
    let company = one("company") ?? "";
    if (!company) {
        const { data: companies } = await supabase.from("companies").select("id").eq("org_id", org.id).limit(2);
        if (companies?.length === 1) company = companies[0].id;
    }

    const filters = { company, from_date: from, to_date: to };
    const [outgoingBills, incomingBills, incomingPayment, outgoingPayment, outgoingBillChart, incomingBillChart, bank, profit] = company
        ? await Promise.all([
              loadCardSum("sales_invoice", "base_net_total", filters),
              loadCardSum("purchase_invoice", "base_net_total", filters),
              loadCardSum("payment_entry", "base_received_amount", filters),
              loadCardSum("payment_entry", "base_paid_amount", filters),
              loadChartTimeseries("sales_invoice", "base_net_total", filters),
              loadChartTimeseries("purchase_invoice", "base_net_total", filters),
              loadBankBalance(filters),
              chartYear
                  ? loadProfitAndLoss({
                        company,
                        basis: "Fiscal Year",
                        fromFiscalYear: chartYear.id,
                        toFiscalYear: chartYear.id,
                        from: chartYear.year_start_date,
                        to: chartYear.year_end_date,
                        periodicity: "Yearly",
                        accumulated: false,
                        showZero: false,
                    })
                  : Promise.resolve(null),
          ])
        : [UNAVAILABLE_CARD, UNAVAILABLE_CARD, UNAVAILABLE_CARD, UNAVAILABLE_CARD, EMPTY_SERIES, EMPTY_SERIES, EMPTY_SERIES, null];

    return (
        <AccountsDashboard
            orgSlug={org.slug}
            companyId={company}
            from={from}
            to={to}
            outgoingBills={outgoingBills}
            incomingBills={incomingBills}
            incomingPayment={incomingPayment}
            outgoingPayment={outgoingPayment}
            profit={profit?.chart ?? EMPTY_PROFIT}
            profitError={profit?.error}
            outgoingBillChart={outgoingBillChart}
            incomingBillChart={incomingBillChart}
            bank={bank}
            error={company ? undefined : "Company is mandatory"}
        />
    );
}

async function ItemRoute({ params, searchParams }: ItemPageProps) {
    const { org, module: moduleId, slug } = await params;
    if (!getModule(moduleId)) notFound();

    const d = slug.length <= 2 ? getDoctype(moduleId, slug[0]) : undefined;
    if (d?.single) {
        if (slug.length === 1) return SingleRoute({ d, orgSlug: org });
        notFound();
    }
    if (d && slug.length === 1) return ListRoute({ d, orgSlug: org, searchParams });
    if (d && slug[1] === "new") return FormRoute({ d, orgSlug: org, id: null, searchParams });
    if (d && UUID.test(slug[1])) return FormRoute({ d, orgSlug: org, id: slug[1] });

    const path = [moduleId, ...slug].join("/");
    const link = findLinkForPath(path);
    if (!link) notFound();
    if (link.target.kind === "report" && link.target.report === "General Ledger") {
        return GeneralLedgerRoute({ orgSlug: org, searchParams });
    }
    if (link.target.kind === "report" && link.target.report === "Stock Ledger") {
        return StockLedgerRoute({ orgSlug: org, searchParams });
    }
    if (link.target.kind === "report" && link.target.report === "Stock Balance") {
        return StockBalanceRoute({ orgSlug: org, searchParams });
    }
    if (link.target.kind === "report" && link.target.report === "Trial Balance") {
        return TrialBalanceRoute({ orgSlug: org, searchParams });
    }
    if (link.target.kind === "report" && link.target.report === "Trial Balance for Party") {
        return TrialBalanceForPartyRoute({ orgSlug: org, searchParams });
    }
    if (link.target.kind === "report" && link.target.report === "Profit and Loss Statement") {
        return ProfitAndLossRoute({ orgSlug: org, searchParams });
    }
    if (link.target.kind === "report" && link.target.report === "Balance Sheet") {
        return BalanceSheetRoute({ orgSlug: org, searchParams });
    }
    if (link.target.kind === "report" && link.target.report === "Cash Flow") {
        return CashFlowRoute({ orgSlug: org, searchParams });
    }
    if (link.target.kind === "dashboard" && moduleId === "accounts") {
        return AccountsDashboardRoute({ orgSlug: org, searchParams });
    }
    if (link.target.kind === "dashboard" && moduleId === "stock") {
        return StockDashboardRoute({ orgSlug: org, searchParams });
    }

    return <PlaceholderPage title={link.label} description={describe(link, path)} phase={link.phase} />;
}

export default function ItemPage(props: ItemPageProps) {
    return ItemRoute(props);
}
