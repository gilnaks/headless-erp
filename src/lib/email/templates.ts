/**
 * App-level email templates, shared by every organization (not rows of `email_template`). Same placeholder syntax
 * as Email Template (`render.ts`).
 */
export type AppTemplate = { name: string; subject: string; html: string };

/** Invitation email (00-setup §3.4). `doc` = { organization, invite_url, expires_on }, `user` = the inviter. */
export const INVITATION_TEMPLATE: AppTemplate = {
    name: "Invitation",
    subject: "{{user.full_name}} invited you to {{doc.organization}}",
    html: [
        "<p>Hello,</p>",
        "<p>{{user.full_name}} invited you to join <b>{{doc.organization}}</b>.</p>",
        '<p><a href="{{doc.invite_url}}">Accept the invitation</a></p>',
        "<p>The link works until {{date doc.expires_on}}. If you were not expecting this email, you can ignore it.</p>",
    ].join("\n"),
};

/** Default for a form's "Email" action. `doc` = the record plus { doctype, name, print_url }. */
export const SEND_DOCUMENT_TEMPLATE: AppTemplate = {
    name: "Send Document",
    subject: "{{doc.doctype}} {{doc.name}}",
    html: [
        "<p>Hello,</p>",
        "<p>Please find {{doc.doctype}} <b>{{doc.name}}</b> at the link below.</p>",
        '<p><a href="{{doc.print_url}}">View {{doc.doctype}} {{doc.name}}</a></p>',
        "<p>Regards,<br>{{user.full_name}}<br>{{company.company_name}}</p>",
    ].join("\n"),
};

export const APP_TEMPLATES: readonly AppTemplate[] = [SEND_DOCUMENT_TEMPLATE, INVITATION_TEMPLATE];
