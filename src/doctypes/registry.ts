import { account } from "./accounts/account";
import { accountCategory } from "./accounts/account-category";
import { accountsSettings } from "./accounts/accounts-settings";
import { costCenter } from "./accounts/cost-center";
import { currencyExchange } from "./accounts/currency-exchange";
import { fiscalYear } from "./accounts/fiscal-year";
import { itemTaxTemplate } from "./accounts/item-tax-template";
import { journalEntry } from "./accounts/journal-entry";
import { modeOfPayment } from "./accounts/mode-of-payment";
import { partyType } from "./accounts/party-type";
import { paymentEntry } from "./accounts/payment-entry";
import { paymentTerm } from "./accounts/payment-term";
import { paymentTermsTemplate } from "./accounts/payment-terms-template";
import { purchaseTaxesAndChargesTemplate } from "./accounts/purchase-taxes-and-charges-template";
import { salesTaxesAndChargesTemplate } from "./accounts/sales-taxes-and-charges-template";
import { taxCategory } from "./accounts/tax-category";
import { taxRule } from "./accounts/tax-rule";
import { supplier } from "./buying/supplier";
import { supplierGroup } from "./buying/supplier-group";
import type { Doctype } from "./define";
import { customer } from "./selling/customer";
import { customerGroup } from "./selling/customer-group";
import { industryType } from "./selling/industry-type";
import { productBundle } from "./selling/product-bundle";
import { salesPerson } from "./selling/sales-person";
import { territory } from "./selling/territory";
import { address } from "./setup/address";
import { authorizationRule } from "./setup/authorization-rule";
import { branch } from "./setup/branch";
import { company } from "./setup/company";
import { contact } from "./setup/contact";
import { department } from "./setup/department";
import { designation } from "./setup/designation";
import { emailAccount } from "./setup/email-account";
import { emailTemplate } from "./setup/email-template";
import { globalDefaults } from "./setup/global-defaults";
import { holidayList } from "./setup/holiday-list";
import { letterHead } from "./setup/letter-head";
import { printFormat } from "./setup/print-format";
import { printHeading } from "./setup/print-heading";
import { printSettings } from "./setup/print-settings";
import { role } from "./setup/role";
import { roleProfile } from "./setup/role-profile";
import { systemSettings } from "./setup/system-settings";
import { termsAndConditions } from "./setup/terms-and-conditions";
import { userPermission } from "./setup/user-permission";
import { brand } from "./stock/brand";
import { item } from "./stock/item";
import { itemGroup } from "./stock/item-group";
import { itemPrice } from "./stock/item-price";
import { materialRequest } from "./stock/material-request";
import { priceList } from "./stock/price-list";
import { stockEntry } from "./stock/stock-entry";
import { stockEntryType } from "./stock/stock-entry-type";
import { stockReconciliation } from "./stock/stock-reconciliation";
import { stockSettings } from "./stock/stock-settings";
import { uom } from "./stock/uom";
import { uomCategory } from "./stock/uom-category";
import { uomConversionFactor } from "./stock/uom-conversion-factor";
import { warehouse } from "./stock/warehouse";
import { warehouseType } from "./stock/warehouse-type";

/** Every doctype with a working list/form. Keep `doctype_meta` (migrations) in sync. */
export const DOCTYPES: readonly Doctype[] = [
    company,
    globalDefaults,
    systemSettings,
    role,
    roleProfile,
    userPermission,
    authorizationRule,
    branch,
    designation,
    department,
    holidayList,
    fiscalYear,
    accountCategory,
    account,
    accountsSettings,
    costCenter,
    modeOfPayment,
    paymentTerm,
    paymentTermsTemplate,
    purchaseTaxesAndChargesTemplate,
    salesTaxesAndChargesTemplate,
    itemTaxTemplate,
    journalEntry,
    paymentEntry,
    currencyExchange,
    partyType,
    taxCategory,
    taxRule,
    letterHead,
    printSettings,
    printFormat,
    address,
    contact,
    termsAndConditions,
    printHeading,
    emailAccount,
    emailTemplate,
    uom,
    uomCategory,
    uomConversionFactor,
    stockEntryType,
    stockEntry,
    materialRequest,
    stockReconciliation,
    stockSettings,
    warehouseType,
    warehouse,
    item,
    itemGroup,
    brand,
    priceList,
    itemPrice,
    customer,
    customerGroup,
    salesPerson,
    territory,
    industryType,
    productBundle,
    supplier,
    supplierGroup,
];

/** Manufacturing reuses the stock document; the descriptor stays on the stock module. */
const ROUTE_ALIASES: Record<string, { module: string; slug: string }> = {
    "buying/material-request": { module: "stock", slug: "material-request" },
    "manufacturing/stock-entry": { module: "stock", slug: "stock-entry" },
};

export function getDoctype(module: string, slug: string): Doctype | undefined {
    const alias = ROUTE_ALIASES[`${module}/${slug}`];
    if (alias) return DOCTYPES.find((d) => d.module === alias.module && d.slug === alias.slug);
    return DOCTYPES.find((d) => d.module === module && d.slug === slug);
}

export function getDoctypeByName(name: string): Doctype | undefined {
    return DOCTYPES.find((d) => d.doctype === name);
}
