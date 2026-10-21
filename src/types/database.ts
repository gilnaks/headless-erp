export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  app: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      _account_by_name: {
        Args: { p_company: string; p_name: string }
        Returns: string
      }
      _account_by_type: {
        Args: { p_company: string; p_root?: string; p_type: string }
        Returns: string
      }
      accept_invitation: { Args: { p_token: string }; Returns: string }
      account_display_name: {
        Args: { p_abbr: string; p_name: string; p_number: string }
        Returns: string
      }
      address_refresh: { Args: { p_address: string }; Returns: undefined }
      allowed_records: {
        Args: { p_doctype: string; p_for?: string; p_org: string }
        Returns: string[]
      }
      amend_doc: { Args: { p_doctype: string; p_id: string }; Returns: Json }
      authorization_check_level: {
        Args: {
          p_company: string
          p_doctype: string
          p_level: number
          p_org: string
          p_roles: string[]
          p_total: number
          p_user: string
        }
        Returns: undefined
      }
      auto_create_fiscal_year: { Args: never; Returns: number }
      can_write_file: { Args: { p_name: string }; Returns: boolean }
      cancel_doc: { Args: { p_doctype: string; p_id: string }; Returns: Json }
      card_stock: { Args: { p_filters: Json }; Returns: Json }
      card_sum: {
        Args: { p_doctype: string; p_field: string; p_filters: Json }
        Returns: Json
      }
      chart_account_balance_timeline: {
        Args: { p_filters: Json }
        Returns: Json
      }
      chart_stock: { Args: { p_chart: string; p_filters: Json }; Returns: Json }
      chart_timeseries: {
        Args: {
          p_date_field: string
          p_doctype: string
          p_field: string
          p_filters: Json
          p_interval: string
          p_points: number
        }
        Returns: Json
      }
      coa_account_categories: { Args: { p_tree: Json }; Returns: string[] }
      coa_template_nodes: {
        Args: { p_template: string }
        Returns: {
          account_category: string
          account_name: string
          account_number: string
          account_type: string
          idx: number
          is_group: boolean
          node_key: string
          parent_key: string
          root_type: string
          tax_rate: number
        }[]
      }
      coa_template_preview: {
        Args: { p_template: string }
        Returns: {
          account: string
          account_number: string
          account_type: string
          depth: number
          idx: number
          is_group: boolean
          parent_account: string
          root_type: string
        }[]
      }
      coa_templates_for_country: {
        Args: { p_country: string }
        Returns: {
          is_default: boolean
          name: string
        }[]
      }
      company_abbr: { Args: { p_company_name: string }; Returns: string }
      company_address: {
        Args: { p_company: string; p_kind?: string }
        Returns: Database["public"]["Tables"]["address"]["Row"][]
        SetofOptions: {
          from: "*"
          to: "address"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      company_allowed: {
        Args: { p_company: string; p_for?: string; p_org: string }
        Returns: boolean
      }
      contact_refresh: { Args: { p_contact: string }; Returns: undefined }
      copy_item_group_details: { Args: { p_item: string }; Returns: undefined }
      copy_uoms: { Args: { p_all: boolean; p_org: string }; Returns: undefined }
      create_charts: { Args: { p_company: string }; Returns: undefined }
      create_company: { Args: { p: Json }; Returns: Json }
      create_default_tax_templates: {
        Args: { p_company: string }
        Returns: undefined
      }
      create_invitation: {
        Args: {
          p_email: string
          p_org: string
          p_role_profile: string
          p_roles: string[]
        }
        Returns: Json
      }
      create_organization: { Args: { p: Json }; Returns: Json }
      custom_access_token_hook: { Args: { event: Json }; Returns: Json }
      customer_sales_team_refresh: {
        Args: { p_customer: string }
        Returns: undefined
      }
      delete_doc: {
        Args: { p_doctype: string; p_id: string }
        Returns: undefined
      }
      doc_system_columns: { Args: never; Returns: string[] }
      doc_writable_columns: {
        Args: { p_exclude?: string[]; p_keys: string[]; p_table: string }
        Returns: string[]
      }
      email_sender: {
        Args: { p_account?: string; p_company?: string; p_org: string }
        Returns: {
          add_signature: boolean
          always_use_account_email_id_as_sender: boolean
          always_use_account_name_as_sender_name: boolean
          api_key: string
          email_account_id: string
          email_account_name: string
          email_id: string
          footer: string
          signature: string
        }[]
      }
      enable_org_currency: {
        Args: { p_code: string; p_org: string }
        Returns: undefined
      }
      file_doctype: { Args: { p_name: string }; Returns: string }
      file_org: { Args: { p_name: string }; Returns: string }
      fiscal_year_check_overlap: { Args: { p_fy: string }; Returns: undefined }
      fiscal_year_name: {
        Args: { p_end: string; p_start: string }
        Returns: string
      }
      get_customer_group_details: {
        Args: { p_customer: string }
        Returns: undefined
      }
      get_exchange_rate: {
        Args: {
          p_date: string
          p_from: string
          p_org: string
          p_side?: string
          p_to: string
        }
        Returns: number
      }
      get_item_details: { Args: { p: Json }; Returns: Json }
      get_item_tax_map: {
        Args: { p_company: string; p_taxes: Json; p_template: string }
        Returns: Json
      }
      get_outstanding_reference_documents: {
        Args: {
          p_account: string
          p_amount: number
          p_company: string
          p_party: string
          p_party_type: string
        }
        Returns: Json
      }
      get_party_account: {
        Args: { p_company: string; p_party: string; p_party_type: string }
        Returns: string
      }
      get_supplier_group_details: {
        Args: { p_supplier: string }
        Returns: undefined
      }
      get_tax_template: {
        Args: { p_args: Json; p_date: string }
        Returns: string
      }
      has_perm: {
        Args: { p_action: string; p_doctype: string; p_org: string }
        Returns: boolean
      }
      has_role: { Args: { p_org: string; p_role: string }; Returns: boolean }
      holiday_list_refresh: { Args: { p_list: string }; Returns: undefined }
      html_attr_allowed: {
        Args: { p_attr: string; p_tag: string }
        Returns: boolean
      }
      html_clean_tag: {
        Args: { p_name: string; p_raw: string; p_self: boolean }
        Returns: string
      }
      html_filter_style: { Args: { p_style: string }; Returns: string }
      html_url_ok: {
        Args: { p_attr: string; p_tag: string; p_value: string }
        Returns: boolean
      }
      import_uoms: { Args: { p_org: string }; Returns: number }
      invitation_preview: { Args: { p_token: string }; Returns: Json }
      is_half_holiday: {
        Args: { p_date?: string; p_list: string }
        Returns: boolean
      }
      is_holiday: {
        Args: { p_date?: string; p_list: string }
        Returns: boolean
      }
      is_member: { Args: { p_org: string }; Returns: boolean }
      is_printable: { Args: { p_doctype: string }; Returns: boolean }
      item_tax_require_rows: {
        Args: { p_template: string }
        Returns: undefined
      }
      journal_entry_gl_map: { Args: { p_id: string }; Returns: Json }
      jsonb_pick: { Args: { p: Json; p_keys: string[] }; Returns: Json }
      locked_permission_doctypes: { Args: never; Returns: string[] }
      make_gl_entries: {
        Args: { p_entries: Json; p_opts?: Json }
        Returns: undefined
      }
      make_sl_entries: {
        Args: { p_entries: Json; p_opts?: Json }
        Returns: undefined
      }
      make_stock_entry_from_material_request: {
        Args: { p_id: string }
        Returns: Json
      }
      make_stock_gl_entries: {
        Args: { p_voucher_id: string; p_voucher_type: string }
        Returns: undefined
      }
      material_request_set_status: {
        Args: { p_id: string; p_status: string }
        Returns: Json
      }
      material_request_status: { Args: { p_id: string }; Returns: string }
      next_name: {
        Args: {
          p_company: string
          p_org: string
          p_posting_date?: string
          p_series: string
        }
        Returns: string
      }
      on_cancel__material_request: {
        Args: { p_id: string }
        Returns: undefined
      }
      on_cancel__product_bundle: { Args: { p_id: string }; Returns: undefined }
      on_cancel__stock_entry: { Args: { p_id: string }; Returns: undefined }
      on_cancel__stock_reconciliation: {
        Args: { p_id: string }
        Returns: undefined
      }
      on_submit__journal_entry: { Args: { p_id: string }; Returns: undefined }
      on_submit__material_request: {
        Args: { p_id: string }
        Returns: undefined
      }
      on_submit__payment_entry: { Args: { p_id: string }; Returns: undefined }
      on_submit__product_bundle: { Args: { p_id: string }; Returns: undefined }
      on_submit__stock_entry: { Args: { p_id: string }; Returns: undefined }
      on_submit__stock_reconciliation: {
        Args: { p_id: string }
        Returns: undefined
      }
      onboarding_complete: {
        Args: { p_org: string; p_step: string }
        Returns: undefined
      }
      onboarding_dismiss: { Args: { p_org: string }; Returns: undefined }
      onboarding_skip: {
        Args: { p_org: string; p_step: string }
        Returns: undefined
      }
      org_member_directory: {
        Args: { p_org: string }
        Returns: {
          avatar_url: string
          created_at: string
          email: string
          full_name: string
          is_owner: boolean
          last_sign_in_at: string
          role_profile: string
          roles: string[]
          status: string
          user_id: string
        }[]
      }
      orgs_with_perm: {
        Args: { p_action: string; p_doctype: string }
        Returns: string[]
      }
      orgs_with_role: { Args: { p_role: string }; Returns: string[] }
      party_addresses: {
        Args: { p_doctype: string; p_id: string }
        Returns: Database["public"]["Tables"]["address"]["Row"][]
        SetofOptions: {
          from: "*"
          to: "address"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      party_contacts: {
        Args: { p_doctype: string; p_id: string }
        Returns: Database["public"]["Tables"]["contact"]["Row"][]
        SetofOptions: {
          from: "*"
          to: "contact"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      payment_entry_gl_map: { Args: { p_id: string }; Returns: Json }
      payment_terms_template_refresh: {
        Args: { p_template: string }
        Returns: undefined
      }
      print_format_clear_default: {
        Args: { p_doc_type: string; p_keep: string; p_org: string }
        Returns: undefined
      }
      provision_organization: { Args: { p: Json }; Returns: Json }
      record_allowed: {
        Args: {
          p_doctype: string
          p_for?: string
          p_org: string
          p_record: string
        }
        Returns: boolean
      }
      refresh_batch_qty: { Args: { p_batch: string }; Returns: undefined }
      refresh_indented_qty: {
        Args: { p_item: string; p_org: string; p_warehouse: string }
        Returns: undefined
      }
      refresh_material_request: {
        Args: { p_from_stock_entry: boolean; p_id: string }
        Returns: undefined
      }
      refresh_outstanding: {
        Args: { p_voucher_id: string; p_voucher_type: string }
        Returns: undefined
      }
      reorder_items: { Args: never; Returns: number }
      report_balance_sheet: { Args: { p_filters: Json }; Returns: Json }
      report_cash_flow: { Args: { p_filters: Json }; Returns: Json }
      report_general_ledger: { Args: { p_filters: Json }; Returns: Json }
      report_profit_and_loss: { Args: { p_filters: Json }; Returns: Json }
      report_stock_ageing: { Args: { p_filters: Json }; Returns: Json }
      report_stock_balance: { Args: { p_filters: Json }; Returns: Json }
      report_stock_ledger: { Args: { p_filters: Json }; Returns: Json }
      report_stock_projected_qty: { Args: { p_filters: Json }; Returns: Json }
      report_trial_balance: { Args: { p_filters: Json }; Returns: Json }
      report_trial_balance_for_party: {
        Args: { p_filters: Json }
        Returns: Json
      }
      repost_item_valuation: {
        Args: { p_from: string; p_item: string; p_warehouse: string }
        Returns: undefined
      }
      resend_invitation: { Args: { p_id: string }; Returns: Json }
      reserved_slugs: { Args: never; Returns: string[] }
      reset_role_permissions: {
        Args: { p_doctype: string; p_org: string }
        Returns: number
      }
      reverse_gl_entries: {
        Args: { p_voucher_id: string; p_voucher_type: string }
        Returns: undefined
      }
      round: { Args: { p_precision: number; p_value: number }; Returns: number }
      sanitize_doc_payload: {
        Args: { p_doctype: string; p_payload: Json }
        Returns: Json
      }
      sanitize_html: { Args: { p_html: string }; Returns: string }
      save_doc: { Args: { p_doctype: string; p_payload: Json }; Returns: Json }
      save_doc_children: {
        Args: {
          p_meta: Database["public"]["Tables"]["doctype_meta"]["Row"]
          p_org: string
          p_parent: string
          p_payload: Json
        }
        Returns: undefined
      }
      search_link: {
        Args: {
          p_doctype: string
          p_ids?: string[]
          p_org: string
          p_q?: string
        }
        Returns: {
          id: string
          label: string
        }[]
      }
      seed_account_categories: { Args: { p_org: string }; Returns: undefined }
      seed_cost_centers: { Args: { p_company: string }; Returns: undefined }
      seed_customer_groups: { Args: { p_org: string }; Returns: undefined }
      seed_department_root: { Args: { p_org: string }; Returns: string }
      seed_departments: { Args: { p_company: string }; Returns: undefined }
      seed_designations: { Args: { p_org: string }; Returns: undefined }
      seed_item_groups: { Args: { p_org: string }; Returns: undefined }
      seed_modes_of_payment: { Args: { p_org: string }; Returns: undefined }
      seed_onboarding: { Args: { p_org: string }; Returns: undefined }
      seed_party_types: { Args: { p_org: string }; Returns: undefined }
      seed_price_lists: {
        Args: { p_currency: string; p_org: string }
        Returns: undefined
      }
      seed_print_formats: {
        Args: { p_doctype?: string; p_org: string }
        Returns: undefined
      }
      seed_print_headings: { Args: { p_org: string }; Returns: undefined }
      seed_sales_persons: { Args: { p_org: string }; Returns: undefined }
      seed_stock_entry_types: { Args: { p_org: string }; Returns: undefined }
      seed_supplier_groups: { Args: { p_org: string }; Returns: undefined }
      seed_territories: { Args: { p_org: string }; Returns: undefined }
      seed_uoms: { Args: { p_org: string }; Returns: undefined }
      seed_warehouse_types: { Args: { p_org: string }; Returns: undefined }
      seed_warehouses: { Args: { p_company: string }; Returns: undefined }
      set_default_accounts: { Args: { p_company: string }; Returns: undefined }
      set_email_account_key: {
        Args: { p_id: string; p_secret: string }
        Returns: undefined
      }
      set_mode_of_payment_account: {
        Args: { p_company: string }
        Returns: undefined
      }
      submit_doc: { Args: { p_doctype: string; p_id: string }; Returns: Json }
      sync_role_permissions: { Args: { p_org?: string }; Returns: undefined }
      tax_account_for: {
        Args: { p_account: Json; p_company: string }
        Returns: string
      }
      tax_template_name: {
        Args: { p_company: string; p_title: string }
        Returns: string
      }
      tree_label: { Args: { p_id: string }; Returns: unknown }
      uom_names_curated: { Args: never; Returns: string[] }
      update_bin_qty: {
        Args: { p_item: string; p_warehouse: string }
        Returns: undefined
      }
      user_org_ids: { Args: never; Returns: string[] }
      user_roles: { Args: { p_org: string }; Returns: string[] }
      validate_approving_authority: {
        Args: {
          p_company: string
          p_doctype: string
          p_total: number
          p_user?: string
        }
        Returns: undefined
      }
      validate_country_currency: {
        Args: { p_country: string; p_currency: string }
        Returns: undefined
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      account: {
        Row: {
          account_category_id: string | null
          account_currency: string
          account_name: string
          account_number: string | null
          account_type: string | null
          balance_must_be: string
          company_id: string
          created_at: string
          created_by: string | null
          disabled: boolean
          freeze_account: string
          id: string
          include_in_gross: boolean
          is_group: boolean
          name: string
          org_id: string
          parent_id: string | null
          path: unknown
          report_type: string
          root_type: string
          tax_rate: number
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          account_category_id?: string | null
          account_currency: string
          account_name: string
          account_number?: string | null
          account_type?: string | null
          balance_must_be?: string
          company_id: string
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          freeze_account?: string
          id?: string
          include_in_gross?: boolean
          is_group?: boolean
          name: string
          org_id: string
          parent_id?: string | null
          path: unknown
          report_type: string
          root_type: string
          tax_rate?: number
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          account_category_id?: string | null
          account_currency?: string
          account_name?: string
          account_number?: string | null
          account_type?: string | null
          balance_must_be?: string
          company_id?: string
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          freeze_account?: string
          id?: string
          include_in_gross?: boolean
          is_group?: boolean
          name?: string
          org_id?: string
          parent_id?: string | null
          path?: unknown
          report_type?: string
          root_type?: string
          tax_rate?: number
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "account_org_id_account_category_id_fkey"
            columns: ["org_id", "account_category_id"]
            isOneToOne: false
            referencedRelation: "account_category"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "account_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "account_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "account_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      account_category: {
        Row: {
          account_category_name: string
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          org_id: string
          root_type: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          account_category_name: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          org_id: string
          root_type?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          account_category_name?: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          org_id?: string
          root_type?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "account_category_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      accounts_settings: {
        Row: {
          add_taxes_from_item_tax_template: boolean
          add_taxes_from_taxes_and_charges_template: boolean
          allow_stale: boolean
          auto_reconcile_payments: boolean
          automatically_fetch_payment_terms: boolean
          book_asset_depreciation_entry_automatically: boolean
          book_stock_expense_gl_entries: boolean
          book_tax_discount_loss: boolean
          calculate_depr_using_total_days: boolean
          check_supplier_invoice_uniqueness: boolean
          confirm_before_resetting_posting_date: boolean
          created_at: string
          created_by: string | null
          credit_controller: string | null
          default_ageing_range: string
          delete_linked_ledger_entries: boolean
          determine_address_tax_category_from: string
          enable_common_party_accounting: boolean
          enable_discounts_and_margin: boolean
          enable_fuzzy_matching: boolean
          enable_immutable_ledger: boolean
          enable_overdue_billing_threshold: boolean
          enable_party_matching: boolean
          exchange_gain_loss_posting_date: string
          general_ledger_remarks_length: number
          id: string
          ignore_account_closing_balance: boolean
          ignore_is_opening_check_for_reporting: boolean
          make_payment_via_journal_entry: boolean
          merge_similar_account_heads: boolean
          org_id: string
          over_billing_allowance: number
          receivable_payable_remarks_length: number
          role_allowed_to_bypass_overdue_billing: string | null
          role_allowed_to_over_bill: string | null
          role_to_notify_on_depreciation_failure: string | null
          round_row_wise_tax: boolean
          show_balance_in_coa: boolean
          show_inclusive_tax_in_print: boolean
          show_payment_schedule_in_print: boolean
          show_taxes_as_table_in_print: boolean
          stale_days: number
          transfer_match_days: number
          unlink_advance_payment_on_cancelation_of_order: boolean
          unlink_payment_on_cancellation_of_invoice: boolean
          updated_at: string
          updated_by: string | null
          use_legacy_budget_controller: boolean
        }
        Insert: {
          add_taxes_from_item_tax_template?: boolean
          add_taxes_from_taxes_and_charges_template?: boolean
          allow_stale?: boolean
          auto_reconcile_payments?: boolean
          automatically_fetch_payment_terms?: boolean
          book_asset_depreciation_entry_automatically?: boolean
          book_stock_expense_gl_entries?: boolean
          book_tax_discount_loss?: boolean
          calculate_depr_using_total_days?: boolean
          check_supplier_invoice_uniqueness?: boolean
          confirm_before_resetting_posting_date?: boolean
          created_at?: string
          created_by?: string | null
          credit_controller?: string | null
          default_ageing_range?: string
          delete_linked_ledger_entries?: boolean
          determine_address_tax_category_from?: string
          enable_common_party_accounting?: boolean
          enable_discounts_and_margin?: boolean
          enable_fuzzy_matching?: boolean
          enable_immutable_ledger?: boolean
          enable_overdue_billing_threshold?: boolean
          enable_party_matching?: boolean
          exchange_gain_loss_posting_date?: string
          general_ledger_remarks_length?: number
          id?: string
          ignore_account_closing_balance?: boolean
          ignore_is_opening_check_for_reporting?: boolean
          make_payment_via_journal_entry?: boolean
          merge_similar_account_heads?: boolean
          org_id: string
          over_billing_allowance?: number
          receivable_payable_remarks_length?: number
          role_allowed_to_bypass_overdue_billing?: string | null
          role_allowed_to_over_bill?: string | null
          role_to_notify_on_depreciation_failure?: string | null
          round_row_wise_tax?: boolean
          show_balance_in_coa?: boolean
          show_inclusive_tax_in_print?: boolean
          show_payment_schedule_in_print?: boolean
          show_taxes_as_table_in_print?: boolean
          stale_days?: number
          transfer_match_days?: number
          unlink_advance_payment_on_cancelation_of_order?: boolean
          unlink_payment_on_cancellation_of_invoice?: boolean
          updated_at?: string
          updated_by?: string | null
          use_legacy_budget_controller?: boolean
        }
        Update: {
          add_taxes_from_item_tax_template?: boolean
          add_taxes_from_taxes_and_charges_template?: boolean
          allow_stale?: boolean
          auto_reconcile_payments?: boolean
          automatically_fetch_payment_terms?: boolean
          book_asset_depreciation_entry_automatically?: boolean
          book_stock_expense_gl_entries?: boolean
          book_tax_discount_loss?: boolean
          calculate_depr_using_total_days?: boolean
          check_supplier_invoice_uniqueness?: boolean
          confirm_before_resetting_posting_date?: boolean
          created_at?: string
          created_by?: string | null
          credit_controller?: string | null
          default_ageing_range?: string
          delete_linked_ledger_entries?: boolean
          determine_address_tax_category_from?: string
          enable_common_party_accounting?: boolean
          enable_discounts_and_margin?: boolean
          enable_fuzzy_matching?: boolean
          enable_immutable_ledger?: boolean
          enable_overdue_billing_threshold?: boolean
          enable_party_matching?: boolean
          exchange_gain_loss_posting_date?: string
          general_ledger_remarks_length?: number
          id?: string
          ignore_account_closing_balance?: boolean
          ignore_is_opening_check_for_reporting?: boolean
          make_payment_via_journal_entry?: boolean
          merge_similar_account_heads?: boolean
          org_id?: string
          over_billing_allowance?: number
          receivable_payable_remarks_length?: number
          role_allowed_to_bypass_overdue_billing?: string | null
          role_allowed_to_over_bill?: string | null
          role_to_notify_on_depreciation_failure?: string | null
          round_row_wise_tax?: boolean
          show_balance_in_coa?: boolean
          show_inclusive_tax_in_print?: boolean
          show_payment_schedule_in_print?: boolean
          show_taxes_as_table_in_print?: boolean
          stale_days?: number
          transfer_match_days?: number
          unlink_advance_payment_on_cancelation_of_order?: boolean
          unlink_payment_on_cancellation_of_invoice?: boolean
          updated_at?: string
          updated_by?: string | null
          use_legacy_budget_controller?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "accounts_settings_org_id_credit_controller_fkey"
            columns: ["org_id", "credit_controller"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["org_id", "name"]
          },
          {
            foreignKeyName: "accounts_settings_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: true
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accounts_settings_org_id_role_allowed_to_bypass_overdue_bi_fkey"
            columns: ["org_id", "role_allowed_to_bypass_overdue_billing"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["org_id", "name"]
          },
          {
            foreignKeyName: "accounts_settings_org_id_role_allowed_to_over_bill_fkey"
            columns: ["org_id", "role_allowed_to_over_bill"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["org_id", "name"]
          },
          {
            foreignKeyName: "accounts_settings_org_id_role_to_notify_on_depreciation_fa_fkey"
            columns: ["org_id", "role_to_notify_on_depreciation_failure"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["org_id", "name"]
          },
        ]
      }
      address: {
        Row: {
          address_line1: string
          address_line2: string | null
          address_title: string | null
          address_type: string
          city: string
          country: string
          county: string | null
          created_at: string
          created_by: string | null
          disabled: boolean
          email_id: string | null
          fax: string | null
          id: string
          is_primary_address: boolean
          is_shipping_address: boolean
          is_your_company_address: boolean
          name: string | null
          org_id: string
          phone: string | null
          pincode: string | null
          state: string | null
          tax_category_id: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          address_line1: string
          address_line2?: string | null
          address_title?: string | null
          address_type?: string
          city: string
          country: string
          county?: string | null
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          email_id?: string | null
          fax?: string | null
          id?: string
          is_primary_address?: boolean
          is_shipping_address?: boolean
          is_your_company_address?: boolean
          name?: string | null
          org_id: string
          phone?: string | null
          pincode?: string | null
          state?: string | null
          tax_category_id?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          address_line1?: string
          address_line2?: string | null
          address_title?: string | null
          address_type?: string
          city?: string
          country?: string
          county?: string | null
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          email_id?: string | null
          fax?: string | null
          id?: string
          is_primary_address?: boolean
          is_shipping_address?: boolean
          is_your_company_address?: boolean
          name?: string | null
          org_id?: string
          phone?: string | null
          pincode?: string | null
          state?: string | null
          tax_category_id?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "address_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "coa_template_country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "address_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "address_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "address_tax_category_fk"
            columns: ["org_id", "tax_category_id"]
            isOneToOne: false
            referencedRelation: "tax_category"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      address_link: {
        Row: {
          id: string
          idx: number
          link_doctype: string
          link_id: string
          link_title: string | null
          org_id: string
          parent_id: string
        }
        Insert: {
          id?: string
          idx: number
          link_doctype: string
          link_id: string
          link_title?: string | null
          org_id: string
          parent_id: string
        }
        Update: {
          id?: string
          idx?: number
          link_doctype?: string
          link_id?: string
          link_title?: string | null
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "address_link_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "address"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      authorization_rule: {
        Row: {
          approving_role: string | null
          approving_user: string | null
          based_on: string
          company_id: string | null
          created_at: string
          created_by: string | null
          id: string
          name: string
          org_id: string
          system_role: string | null
          system_user: string | null
          transaction: string
          updated_at: string
          updated_by: string | null
          value: number
        }
        Insert: {
          approving_role?: string | null
          approving_user?: string | null
          based_on?: string
          company_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          org_id: string
          system_role?: string | null
          system_user?: string | null
          transaction: string
          updated_at?: string
          updated_by?: string | null
          value?: number
        }
        Update: {
          approving_role?: string | null
          approving_user?: string | null
          based_on?: string
          company_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          org_id?: string
          system_role?: string | null
          system_user?: string | null
          transaction?: string
          updated_at?: string
          updated_by?: string | null
          value?: number
        }
        Relationships: [
          {
            foreignKeyName: "authorization_rule_org_id_approving_role_fkey"
            columns: ["org_id", "approving_role"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["org_id", "name"]
          },
          {
            foreignKeyName: "authorization_rule_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "authorization_rule_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "authorization_rule_org_id_system_role_fkey"
            columns: ["org_id", "system_role"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["org_id", "name"]
          },
        ]
      }
      batch: {
        Row: {
          batch_id: string
          batch_qty: number
          created_at: string
          created_by: string | null
          disabled: boolean
          expiry_date: string | null
          id: string
          item_id: string
          manufacturing_date: string | null
          name: string
          org_id: string
          supplier_id: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          batch_id: string
          batch_qty?: number
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          expiry_date?: string | null
          id?: string
          item_id: string
          manufacturing_date?: string | null
          name: string
          org_id: string
          supplier_id?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          batch_id?: string
          batch_qty?: number
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          expiry_date?: string | null
          id?: string
          item_id?: string
          manufacturing_date?: string | null
          name?: string
          org_id?: string
          supplier_id?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "batch_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "batch_org_id_item_id_fkey"
            columns: ["org_id", "item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "batch_org_id_supplier_id_fkey"
            columns: ["org_id", "supplier_id"]
            isOneToOne: false
            referencedRelation: "supplier"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      bin: {
        Row: {
          actual_qty: number
          created_at: string
          id: string
          indented_qty: number
          item_id: string
          ordered_qty: number
          org_id: string
          planned_qty: number
          projected_qty: number
          reserved_qty: number
          reserved_qty_for_production: number
          reserved_qty_for_production_plan: number
          reserved_qty_for_sub_contract: number
          stock_uom_id: string | null
          stock_value: number
          updated_at: string
          updated_by: string | null
          valuation_rate: number
          warehouse_id: string
        }
        Insert: {
          actual_qty?: number
          created_at?: string
          id?: string
          indented_qty?: number
          item_id: string
          ordered_qty?: number
          org_id: string
          planned_qty?: number
          projected_qty?: number
          reserved_qty?: number
          reserved_qty_for_production?: number
          reserved_qty_for_production_plan?: number
          reserved_qty_for_sub_contract?: number
          stock_uom_id?: string | null
          stock_value?: number
          updated_at?: string
          updated_by?: string | null
          valuation_rate?: number
          warehouse_id: string
        }
        Update: {
          actual_qty?: number
          created_at?: string
          id?: string
          indented_qty?: number
          item_id?: string
          ordered_qty?: number
          org_id?: string
          planned_qty?: number
          projected_qty?: number
          reserved_qty?: number
          reserved_qty_for_production?: number
          reserved_qty_for_production_plan?: number
          reserved_qty_for_sub_contract?: number
          stock_uom_id?: string | null
          stock_value?: number
          updated_at?: string
          updated_by?: string | null
          valuation_rate?: number
          warehouse_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bin_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bin_org_id_item_id_fkey"
            columns: ["org_id", "item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "bin_org_id_stock_uom_id_fkey"
            columns: ["org_id", "stock_uom_id"]
            isOneToOne: false
            referencedRelation: "uom"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "bin_org_id_warehouse_id_fkey"
            columns: ["org_id", "warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      branch: {
        Row: {
          branch: string
          created_at: string
          created_by: string | null
          id: string
          org_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          branch: string
          created_at?: string
          created_by?: string | null
          id?: string
          org_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          branch?: string
          created_at?: string
          created_by?: string | null
          id?: string
          org_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "branch_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      brand: {
        Row: {
          brand: string
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          org_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          brand: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          org_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          brand?: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          org_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "brand_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      brand_default: {
        Row: {
          buying_cost_center_id: string | null
          company_id: string
          default_price_list_id: string | null
          default_supplier_id: string | null
          default_warehouse_id: string | null
          expense_account_id: string | null
          id: string
          idx: number
          income_account_id: string | null
          org_id: string
          parent_id: string
          selling_cost_center_id: string | null
        }
        Insert: {
          buying_cost_center_id?: string | null
          company_id: string
          default_price_list_id?: string | null
          default_supplier_id?: string | null
          default_warehouse_id?: string | null
          expense_account_id?: string | null
          id?: string
          idx: number
          income_account_id?: string | null
          org_id: string
          parent_id: string
          selling_cost_center_id?: string | null
        }
        Update: {
          buying_cost_center_id?: string | null
          company_id?: string
          default_price_list_id?: string | null
          default_supplier_id?: string | null
          default_warehouse_id?: string | null
          expense_account_id?: string | null
          id?: string
          idx?: number
          income_account_id?: string | null
          org_id?: string
          parent_id?: string
          selling_cost_center_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "brand_default_org_id_buying_cost_center_id_fkey"
            columns: ["org_id", "buying_cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "brand_default_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "brand_default_org_id_default_price_list_id_fkey"
            columns: ["org_id", "default_price_list_id"]
            isOneToOne: false
            referencedRelation: "price_list"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "brand_default_org_id_default_supplier_id_fkey"
            columns: ["org_id", "default_supplier_id"]
            isOneToOne: false
            referencedRelation: "supplier"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "brand_default_org_id_default_warehouse_id_fkey"
            columns: ["org_id", "default_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "brand_default_org_id_expense_account_id_fkey"
            columns: ["org_id", "expense_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "brand_default_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "brand_default_org_id_income_account_id_fkey"
            columns: ["org_id", "income_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "brand_default_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "brand"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "brand_default_org_id_selling_cost_center_id_fkey"
            columns: ["org_id", "selling_cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      coa_template: {
        Row: {
          disabled: boolean
          name: string
          tree: Json
        }
        Insert: {
          disabled?: boolean
          name: string
          tree: Json
        }
        Update: {
          disabled?: boolean
          name?: string
          tree?: Json
        }
        Relationships: []
      }
      coa_template_file: {
        Row: {
          file_name: string
          template: string
        }
        Insert: {
          file_name: string
          template: string
        }
        Update: {
          file_name?: string
          template?: string
        }
        Relationships: [
          {
            foreignKeyName: "coa_template_file_template_fkey"
            columns: ["template"]
            isOneToOne: false
            referencedRelation: "coa_template"
            referencedColumns: ["name"]
          },
        ]
      }
      companies: {
        Row: {
          abbr: string
          accounts_frozen_till_date: string | null
          accumulated_depreciation_account_id: string | null
          allow_account_creation_against_child_company: boolean
          asset_received_but_not_billed_id: string | null
          auto_err_frequency: string | null
          auto_exchange_rate_revaluation: boolean
          bank_charges_account_id: string | null
          book_advance_payments_in_separate_party_account: boolean
          capital_work_in_progress_account_id: string | null
          chart_of_accounts: string | null
          company_description: string | null
          company_logo: string | null
          company_name: string
          cost_center_id: string | null
          country: string
          create_chart_of_accounts_based_on: string
          created_at: string
          created_by: string | null
          credit_limit: number
          date_of_commencement: string | null
          date_of_establishment: string | null
          date_of_incorporation: string | null
          default_advance_paid_account_id: string | null
          default_advance_received_account_id: string | null
          default_bank_account_id: string | null
          default_buying_terms_id: string | null
          default_cash_account_id: string | null
          default_currency: string
          default_deferred_expense_account_id: string | null
          default_deferred_revenue_account_id: string | null
          default_discount_account_id: string | null
          default_expense_account_id: string | null
          default_fg_warehouse_id: string | null
          default_finance_book_id: string | null
          default_holiday_list_id: string | null
          default_in_transit_warehouse_id: string | null
          default_income_account_id: string | null
          default_inventory_account_id: string | null
          default_letter_head_id: string | null
          default_manufacturing_variance_account_id: string | null
          default_operating_cost_account_id: string | null
          default_payable_account_id: string | null
          default_provisional_account_id: string | null
          default_purchase_price_variance_account_id: string | null
          default_receivable_account_id: string | null
          default_sales_contact_id: string | null
          default_scrap_warehouse_id: string | null
          default_selling_terms_id: string | null
          default_warehouse_for_sales_return_id: string | null
          default_warehouse_id: string | null
          default_wip_warehouse_id: string | null
          depreciation_cost_center_id: string | null
          depreciation_expense_account_id: string | null
          disable_sdbnb_in_sr: boolean
          disabled: boolean
          disposal_account_id: string | null
          domain: string | null
          email: string | null
          enable_item_wise_inventory_account: boolean
          enable_perpetual_inventory: boolean
          enable_provisional_accounting_for_non_stock_items: boolean
          enable_stock_delivered_but_not_billed: boolean
          exception_budget_approver_role: string | null
          exchange_gain_account_id: string | null
          exchange_gain_loss_account_id: string | null
          exchange_loss_account_id: string | null
          existing_company_id: string | null
          expenses_added_to_stock_account_id: string | null
          expenses_added_to_stock_contra_account_id: string | null
          fax: string | null
          id: string
          is_group: boolean
          monthly_sales_target: number
          name: string
          org_id: string
          parent_id: string | null
          path: unknown
          payment_terms_id: string | null
          phone_no: string | null
          purchase_expense_account_id: string | null
          purchase_expense_contra_account_id: string | null
          reconciliation_takes_effect_on: string
          registration_details: string | null
          reporting_currency: string | null
          role_allowed_for_frozen_entries: string | null
          round_off_account_id: string | null
          round_off_cost_center_id: string | null
          round_off_for_opening_id: string | null
          sales_monthly_history: Json | null
          sample_retention_warehouse_id: string | null
          series_for_depreciation_entry: string | null
          service_expense_account_id: string | null
          stock_adjustment_account_id: string | null
          stock_delivered_but_not_billed_id: string | null
          stock_received_but_not_billed_id: string | null
          submit_err_jv: boolean
          tax_id: string | null
          total_monthly_sales: number
          transactions_annual_history: Json | null
          unrealized_exchange_gain_loss_account_id: string | null
          unrealized_profit_loss_account_id: string | null
          updated_at: string
          updated_by: string | null
          valuation_method: string
          website: string | null
          write_off_account_id: string | null
        }
        Insert: {
          abbr: string
          accounts_frozen_till_date?: string | null
          accumulated_depreciation_account_id?: string | null
          allow_account_creation_against_child_company?: boolean
          asset_received_but_not_billed_id?: string | null
          auto_err_frequency?: string | null
          auto_exchange_rate_revaluation?: boolean
          bank_charges_account_id?: string | null
          book_advance_payments_in_separate_party_account?: boolean
          capital_work_in_progress_account_id?: string | null
          chart_of_accounts?: string | null
          company_description?: string | null
          company_logo?: string | null
          company_name: string
          cost_center_id?: string | null
          country: string
          create_chart_of_accounts_based_on?: string
          created_at?: string
          created_by?: string | null
          credit_limit?: number
          date_of_commencement?: string | null
          date_of_establishment?: string | null
          date_of_incorporation?: string | null
          default_advance_paid_account_id?: string | null
          default_advance_received_account_id?: string | null
          default_bank_account_id?: string | null
          default_buying_terms_id?: string | null
          default_cash_account_id?: string | null
          default_currency: string
          default_deferred_expense_account_id?: string | null
          default_deferred_revenue_account_id?: string | null
          default_discount_account_id?: string | null
          default_expense_account_id?: string | null
          default_fg_warehouse_id?: string | null
          default_finance_book_id?: string | null
          default_holiday_list_id?: string | null
          default_in_transit_warehouse_id?: string | null
          default_income_account_id?: string | null
          default_inventory_account_id?: string | null
          default_letter_head_id?: string | null
          default_manufacturing_variance_account_id?: string | null
          default_operating_cost_account_id?: string | null
          default_payable_account_id?: string | null
          default_provisional_account_id?: string | null
          default_purchase_price_variance_account_id?: string | null
          default_receivable_account_id?: string | null
          default_sales_contact_id?: string | null
          default_scrap_warehouse_id?: string | null
          default_selling_terms_id?: string | null
          default_warehouse_for_sales_return_id?: string | null
          default_warehouse_id?: string | null
          default_wip_warehouse_id?: string | null
          depreciation_cost_center_id?: string | null
          depreciation_expense_account_id?: string | null
          disable_sdbnb_in_sr?: boolean
          disabled?: boolean
          disposal_account_id?: string | null
          domain?: string | null
          email?: string | null
          enable_item_wise_inventory_account?: boolean
          enable_perpetual_inventory?: boolean
          enable_provisional_accounting_for_non_stock_items?: boolean
          enable_stock_delivered_but_not_billed?: boolean
          exception_budget_approver_role?: string | null
          exchange_gain_account_id?: string | null
          exchange_gain_loss_account_id?: string | null
          exchange_loss_account_id?: string | null
          existing_company_id?: string | null
          expenses_added_to_stock_account_id?: string | null
          expenses_added_to_stock_contra_account_id?: string | null
          fax?: string | null
          id?: string
          is_group?: boolean
          monthly_sales_target?: number
          name: string
          org_id: string
          parent_id?: string | null
          path: unknown
          payment_terms_id?: string | null
          phone_no?: string | null
          purchase_expense_account_id?: string | null
          purchase_expense_contra_account_id?: string | null
          reconciliation_takes_effect_on?: string
          registration_details?: string | null
          reporting_currency?: string | null
          role_allowed_for_frozen_entries?: string | null
          round_off_account_id?: string | null
          round_off_cost_center_id?: string | null
          round_off_for_opening_id?: string | null
          sales_monthly_history?: Json | null
          sample_retention_warehouse_id?: string | null
          series_for_depreciation_entry?: string | null
          service_expense_account_id?: string | null
          stock_adjustment_account_id?: string | null
          stock_delivered_but_not_billed_id?: string | null
          stock_received_but_not_billed_id?: string | null
          submit_err_jv?: boolean
          tax_id?: string | null
          total_monthly_sales?: number
          transactions_annual_history?: Json | null
          unrealized_exchange_gain_loss_account_id?: string | null
          unrealized_profit_loss_account_id?: string | null
          updated_at?: string
          updated_by?: string | null
          valuation_method?: string
          website?: string | null
          write_off_account_id?: string | null
        }
        Update: {
          abbr?: string
          accounts_frozen_till_date?: string | null
          accumulated_depreciation_account_id?: string | null
          allow_account_creation_against_child_company?: boolean
          asset_received_but_not_billed_id?: string | null
          auto_err_frequency?: string | null
          auto_exchange_rate_revaluation?: boolean
          bank_charges_account_id?: string | null
          book_advance_payments_in_separate_party_account?: boolean
          capital_work_in_progress_account_id?: string | null
          chart_of_accounts?: string | null
          company_description?: string | null
          company_logo?: string | null
          company_name?: string
          cost_center_id?: string | null
          country?: string
          create_chart_of_accounts_based_on?: string
          created_at?: string
          created_by?: string | null
          credit_limit?: number
          date_of_commencement?: string | null
          date_of_establishment?: string | null
          date_of_incorporation?: string | null
          default_advance_paid_account_id?: string | null
          default_advance_received_account_id?: string | null
          default_bank_account_id?: string | null
          default_buying_terms_id?: string | null
          default_cash_account_id?: string | null
          default_currency?: string
          default_deferred_expense_account_id?: string | null
          default_deferred_revenue_account_id?: string | null
          default_discount_account_id?: string | null
          default_expense_account_id?: string | null
          default_fg_warehouse_id?: string | null
          default_finance_book_id?: string | null
          default_holiday_list_id?: string | null
          default_in_transit_warehouse_id?: string | null
          default_income_account_id?: string | null
          default_inventory_account_id?: string | null
          default_letter_head_id?: string | null
          default_manufacturing_variance_account_id?: string | null
          default_operating_cost_account_id?: string | null
          default_payable_account_id?: string | null
          default_provisional_account_id?: string | null
          default_purchase_price_variance_account_id?: string | null
          default_receivable_account_id?: string | null
          default_sales_contact_id?: string | null
          default_scrap_warehouse_id?: string | null
          default_selling_terms_id?: string | null
          default_warehouse_for_sales_return_id?: string | null
          default_warehouse_id?: string | null
          default_wip_warehouse_id?: string | null
          depreciation_cost_center_id?: string | null
          depreciation_expense_account_id?: string | null
          disable_sdbnb_in_sr?: boolean
          disabled?: boolean
          disposal_account_id?: string | null
          domain?: string | null
          email?: string | null
          enable_item_wise_inventory_account?: boolean
          enable_perpetual_inventory?: boolean
          enable_provisional_accounting_for_non_stock_items?: boolean
          enable_stock_delivered_but_not_billed?: boolean
          exception_budget_approver_role?: string | null
          exchange_gain_account_id?: string | null
          exchange_gain_loss_account_id?: string | null
          exchange_loss_account_id?: string | null
          existing_company_id?: string | null
          expenses_added_to_stock_account_id?: string | null
          expenses_added_to_stock_contra_account_id?: string | null
          fax?: string | null
          id?: string
          is_group?: boolean
          monthly_sales_target?: number
          name?: string
          org_id?: string
          parent_id?: string | null
          path?: unknown
          payment_terms_id?: string | null
          phone_no?: string | null
          purchase_expense_account_id?: string | null
          purchase_expense_contra_account_id?: string | null
          reconciliation_takes_effect_on?: string
          registration_details?: string | null
          reporting_currency?: string | null
          role_allowed_for_frozen_entries?: string | null
          round_off_account_id?: string | null
          round_off_cost_center_id?: string | null
          round_off_for_opening_id?: string | null
          sales_monthly_history?: Json | null
          sample_retention_warehouse_id?: string | null
          series_for_depreciation_entry?: string | null
          service_expense_account_id?: string | null
          stock_adjustment_account_id?: string | null
          stock_delivered_but_not_billed_id?: string | null
          stock_received_but_not_billed_id?: string | null
          submit_err_jv?: boolean
          tax_id?: string | null
          total_monthly_sales?: number
          transactions_annual_history?: Json | null
          unrealized_exchange_gain_loss_account_id?: string | null
          unrealized_profit_loss_account_id?: string | null
          updated_at?: string
          updated_by?: string | null
          valuation_method?: string
          website?: string | null
          write_off_account_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "companies_bank_account_fk"
            columns: ["org_id", "default_bank_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_cash_account_fk"
            columns: ["org_id", "default_cash_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_chart_of_accounts_fkey"
            columns: ["chart_of_accounts"]
            isOneToOne: false
            referencedRelation: "coa_template"
            referencedColumns: ["name"]
          },
          {
            foreignKeyName: "companies_cost_center_fk"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "coa_template_country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "companies_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "companies_default_buying_terms_fk"
            columns: ["org_id", "default_buying_terms_id"]
            isOneToOne: false
            referencedRelation: "terms_and_conditions"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_default_currency_fkey"
            columns: ["default_currency"]
            isOneToOne: false
            referencedRelation: "currency"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "companies_default_holiday_list_fkey"
            columns: ["org_id", "default_holiday_list_id"]
            isOneToOne: false
            referencedRelation: "holiday_list"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_default_letter_head_fkey"
            columns: ["org_id", "default_letter_head_id"]
            isOneToOne: false
            referencedRelation: "letter_head"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_default_sales_contact_fkey"
            columns: ["org_id", "default_sales_contact_id"]
            isOneToOne: false
            referencedRelation: "contact"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_default_selling_terms_fk"
            columns: ["org_id", "default_selling_terms_id"]
            isOneToOne: false
            referencedRelation: "terms_and_conditions"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_default_warehouse_fk"
            columns: ["org_id", "default_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_depreciation_cost_center_fk"
            columns: ["org_id", "depreciation_cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_expense_account_fk"
            columns: ["org_id", "default_expense_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_fg_warehouse_fk"
            columns: ["org_id", "default_fg_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_in_transit_warehouse_fk"
            columns: ["org_id", "default_in_transit_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_income_account_fk"
            columns: ["org_id", "default_income_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_inventory_account_fk"
            columns: ["org_id", "default_inventory_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_org_id_exception_budget_approver_role_fkey"
            columns: ["org_id", "exception_budget_approver_role"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["org_id", "name"]
          },
          {
            foreignKeyName: "companies_org_id_existing_company_id_fkey"
            columns: ["org_id", "existing_company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "companies_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_org_id_role_allowed_for_frozen_entries_fkey"
            columns: ["org_id", "role_allowed_for_frozen_entries"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["org_id", "name"]
          },
          {
            foreignKeyName: "companies_payable_account_fk"
            columns: ["org_id", "default_payable_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_payment_terms_fk"
            columns: ["org_id", "payment_terms_id"]
            isOneToOne: false
            referencedRelation: "payment_terms_template"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_receivable_account_fk"
            columns: ["org_id", "default_receivable_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_reporting_currency_fkey"
            columns: ["reporting_currency"]
            isOneToOne: false
            referencedRelation: "currency"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "companies_round_off_account_fk"
            columns: ["org_id", "round_off_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_round_off_cost_center_fk"
            columns: ["org_id", "round_off_cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_sales_return_warehouse_fk"
            columns: ["org_id", "default_warehouse_for_sales_return_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_sample_retention_warehouse_fk"
            columns: ["org_id", "sample_retention_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_scrap_warehouse_fk"
            columns: ["org_id", "default_scrap_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_srbnb_fk"
            columns: ["org_id", "stock_received_but_not_billed_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_stock_adjustment_fk"
            columns: ["org_id", "stock_adjustment_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_wip_warehouse_fk"
            columns: ["org_id", "default_wip_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "companies_write_off_account_fk"
            columns: ["org_id", "write_off_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      contact: {
        Row: {
          address_id: string | null
          company_name: string | null
          created_at: string
          created_by: string | null
          department: string | null
          designation_id: string | null
          email_id: string | null
          first_name: string
          full_name: string | null
          gender: string | null
          id: string
          image: string | null
          is_billing_contact: boolean
          is_primary_contact: boolean
          last_name: string | null
          middle_name: string | null
          mobile_no: string | null
          name: string | null
          org_id: string
          phone: string | null
          salutation: string | null
          status: string
          unsubscribed: boolean
          updated_at: string
          updated_by: string | null
          user_id: string | null
        }
        Insert: {
          address_id?: string | null
          company_name?: string | null
          created_at?: string
          created_by?: string | null
          department?: string | null
          designation_id?: string | null
          email_id?: string | null
          first_name: string
          full_name?: string | null
          gender?: string | null
          id?: string
          image?: string | null
          is_billing_contact?: boolean
          is_primary_contact?: boolean
          last_name?: string | null
          middle_name?: string | null
          mobile_no?: string | null
          name?: string | null
          org_id: string
          phone?: string | null
          salutation?: string | null
          status?: string
          unsubscribed?: boolean
          updated_at?: string
          updated_by?: string | null
          user_id?: string | null
        }
        Update: {
          address_id?: string | null
          company_name?: string | null
          created_at?: string
          created_by?: string | null
          department?: string | null
          designation_id?: string | null
          email_id?: string | null
          first_name?: string
          full_name?: string | null
          gender?: string | null
          id?: string
          image?: string | null
          is_billing_contact?: boolean
          is_primary_contact?: boolean
          last_name?: string | null
          middle_name?: string | null
          mobile_no?: string | null
          name?: string | null
          org_id?: string
          phone?: string | null
          salutation?: string | null
          status?: string
          unsubscribed?: boolean
          updated_at?: string
          updated_by?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "contact_org_id_address_id_fkey"
            columns: ["org_id", "address_id"]
            isOneToOne: false
            referencedRelation: "address"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "contact_org_id_designation_id_fkey"
            columns: ["org_id", "designation_id"]
            isOneToOne: false
            referencedRelation: "designation"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "contact_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      contact_email: {
        Row: {
          email_id: string
          id: string
          idx: number
          is_primary: boolean
          org_id: string
          parent_id: string
        }
        Insert: {
          email_id: string
          id?: string
          idx: number
          is_primary?: boolean
          org_id: string
          parent_id: string
        }
        Update: {
          email_id?: string
          id?: string
          idx?: number
          is_primary?: boolean
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "contact_email_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "contact"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      contact_link: {
        Row: {
          id: string
          idx: number
          link_doctype: string
          link_id: string
          link_title: string | null
          org_id: string
          parent_id: string
        }
        Insert: {
          id?: string
          idx: number
          link_doctype: string
          link_id: string
          link_title?: string | null
          org_id: string
          parent_id: string
        }
        Update: {
          id?: string
          idx?: number
          link_doctype?: string
          link_id?: string
          link_title?: string | null
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "contact_link_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "contact"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      contact_phone: {
        Row: {
          id: string
          idx: number
          is_primary_mobile_no: boolean
          is_primary_phone: boolean
          org_id: string
          parent_id: string
          phone: string
        }
        Insert: {
          id?: string
          idx: number
          is_primary_mobile_no?: boolean
          is_primary_phone?: boolean
          org_id: string
          parent_id: string
          phone: string
        }
        Update: {
          id?: string
          idx?: number
          is_primary_mobile_no?: boolean
          is_primary_phone?: boolean
          org_id?: string
          parent_id?: string
          phone?: string
        }
        Relationships: [
          {
            foreignKeyName: "contact_phone_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "contact"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      cost_center: {
        Row: {
          company_id: string
          cost_center_name: string
          cost_center_number: string | null
          created_at: string
          created_by: string | null
          disabled: boolean
          id: string
          is_group: boolean
          name: string
          org_id: string
          parent_id: string | null
          path: unknown
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          company_id: string
          cost_center_name: string
          cost_center_number?: string | null
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          is_group?: boolean
          name: string
          org_id: string
          parent_id?: string | null
          path: unknown
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          company_id?: string
          cost_center_name?: string
          cost_center_number?: string | null
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          is_group?: boolean
          name?: string
          org_id?: string
          parent_id?: string | null
          path?: unknown
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cost_center_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "cost_center_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cost_center_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      country: {
        Row: {
          code: string | null
          country_name: string
          date_format: string
          time_format: string
          time_zones: string[]
        }
        Insert: {
          code?: string | null
          country_name: string
          date_format?: string
          time_format?: string
          time_zones?: string[]
        }
        Update: {
          code?: string | null
          country_name?: string
          date_format?: string
          time_format?: string
          time_zones?: string[]
        }
        Relationships: []
      }
      country_wise_tax: {
        Row: {
          country: string
          data: Json
        }
        Insert: {
          country: string
          data: Json
        }
        Update: {
          country?: string
          data?: Json
        }
        Relationships: [
          {
            foreignKeyName: "country_wise_tax_country_fkey"
            columns: ["country"]
            isOneToOne: true
            referencedRelation: "coa_template_country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "country_wise_tax_country_fkey"
            columns: ["country"]
            isOneToOne: true
            referencedRelation: "country"
            referencedColumns: ["country_name"]
          },
        ]
      }
      currency: {
        Row: {
          code: string
          currency_name: string
          fraction: string | null
          fraction_units: number | null
          number_format: string | null
          smallest_currency_fraction_value: number | null
          symbol: string | null
          symbol_on_right: boolean
        }
        Insert: {
          code: string
          currency_name: string
          fraction?: string | null
          fraction_units?: number | null
          number_format?: string | null
          smallest_currency_fraction_value?: number | null
          symbol?: string | null
          symbol_on_right?: boolean
        }
        Update: {
          code?: string
          currency_name?: string
          fraction?: string | null
          fraction_units?: number | null
          number_format?: string | null
          smallest_currency_fraction_value?: number | null
          symbol?: string | null
          symbol_on_right?: boolean
        }
        Relationships: []
      }
      currency_exchange: {
        Row: {
          created_at: string
          created_by: string | null
          date: string
          exchange_rate: number
          for_buying: boolean
          for_selling: boolean
          from_currency: string
          id: string
          name: string
          org_id: string
          to_currency: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          date?: string
          exchange_rate: number
          for_buying?: boolean
          for_selling?: boolean
          from_currency: string
          id?: string
          name: string
          org_id: string
          to_currency: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          date?: string
          exchange_rate?: number
          for_buying?: boolean
          for_selling?: boolean
          from_currency?: string
          id?: string
          name?: string
          org_id?: string
          to_currency?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "currency_exchange_from_currency_fkey"
            columns: ["from_currency"]
            isOneToOne: false
            referencedRelation: "currency"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "currency_exchange_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "currency_exchange_to_currency_fkey"
            columns: ["to_currency"]
            isOneToOne: false
            referencedRelation: "currency"
            referencedColumns: ["code"]
          },
        ]
      }
      customer: {
        Row: {
          alias: string | null
          created_at: string
          created_by: string | null
          customer_details: string | null
          customer_group_id: string | null
          customer_name: string
          customer_primary_address: string | null
          customer_primary_contact: string | null
          customer_type: string
          default_currency: string | null
          default_price_list_id: string | null
          disabled: boolean
          dn_required: boolean
          id: string
          industry_id: string | null
          is_frozen: boolean
          language: string | null
          name: string
          on_hold: boolean
          org_id: string
          payment_terms_id: string | null
          release_date: string | null
          so_required: boolean
          tax_category_id: string | null
          tax_id: string | null
          territory_id: string | null
          updated_at: string
          updated_by: string | null
          website: string | null
        }
        Insert: {
          alias?: string | null
          created_at?: string
          created_by?: string | null
          customer_details?: string | null
          customer_group_id?: string | null
          customer_name: string
          customer_primary_address?: string | null
          customer_primary_contact?: string | null
          customer_type?: string
          default_currency?: string | null
          default_price_list_id?: string | null
          disabled?: boolean
          dn_required?: boolean
          id?: string
          industry_id?: string | null
          is_frozen?: boolean
          language?: string | null
          name: string
          on_hold?: boolean
          org_id: string
          payment_terms_id?: string | null
          release_date?: string | null
          so_required?: boolean
          tax_category_id?: string | null
          tax_id?: string | null
          territory_id?: string | null
          updated_at?: string
          updated_by?: string | null
          website?: string | null
        }
        Update: {
          alias?: string | null
          created_at?: string
          created_by?: string | null
          customer_details?: string | null
          customer_group_id?: string | null
          customer_name?: string
          customer_primary_address?: string | null
          customer_primary_contact?: string | null
          customer_type?: string
          default_currency?: string | null
          default_price_list_id?: string | null
          disabled?: boolean
          dn_required?: boolean
          id?: string
          industry_id?: string | null
          is_frozen?: boolean
          language?: string | null
          name?: string
          on_hold?: boolean
          org_id?: string
          payment_terms_id?: string | null
          release_date?: string | null
          so_required?: boolean
          tax_category_id?: string | null
          tax_id?: string | null
          territory_id?: string | null
          updated_at?: string
          updated_by?: string | null
          website?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "customer_org_id_customer_group_id_fkey"
            columns: ["org_id", "customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_group"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_org_id_customer_primary_address_fkey"
            columns: ["org_id", "customer_primary_address"]
            isOneToOne: false
            referencedRelation: "address"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_org_id_customer_primary_contact_fkey"
            columns: ["org_id", "customer_primary_contact"]
            isOneToOne: false
            referencedRelation: "contact"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_org_id_default_price_list_id_fkey"
            columns: ["org_id", "default_price_list_id"]
            isOneToOne: false
            referencedRelation: "price_list"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_org_id_industry_id_fkey"
            columns: ["org_id", "industry_id"]
            isOneToOne: false
            referencedRelation: "industry_type"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_org_id_payment_terms_id_fkey"
            columns: ["org_id", "payment_terms_id"]
            isOneToOne: false
            referencedRelation: "payment_terms_template"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_org_id_tax_category_id_fkey"
            columns: ["org_id", "tax_category_id"]
            isOneToOne: false
            referencedRelation: "tax_category"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_org_id_territory_id_fkey"
            columns: ["org_id", "territory_id"]
            isOneToOne: false
            referencedRelation: "territory"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      customer_credit_limit: {
        Row: {
          bypass_credit_limit_check: boolean
          company_id: string
          credit_limit: number
          id: string
          idx: number
          org_id: string
          parent_id: string
        }
        Insert: {
          bypass_credit_limit_check?: boolean
          company_id: string
          credit_limit?: number
          id?: string
          idx: number
          org_id: string
          parent_id: string
        }
        Update: {
          bypass_credit_limit_check?: boolean
          company_id?: string
          credit_limit?: number
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_credit_limit_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_credit_limit_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_credit_limit_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "customer"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      customer_group: {
        Row: {
          created_at: string
          created_by: string | null
          customer_group_name: string
          default_price_list_id: string | null
          id: string
          is_group: boolean
          org_id: string
          parent_id: string | null
          path: unknown
          payment_terms_id: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          customer_group_name: string
          default_price_list_id?: string | null
          id?: string
          is_group?: boolean
          org_id: string
          parent_id?: string | null
          path: unknown
          payment_terms_id?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          customer_group_name?: string
          default_price_list_id?: string | null
          id?: string
          is_group?: boolean
          org_id?: string
          parent_id?: string | null
          path?: unknown
          payment_terms_id?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "customer_group_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_group_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "customer_group"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_group_payment_terms_fk"
            columns: ["org_id", "payment_terms_id"]
            isOneToOne: false
            referencedRelation: "payment_terms_template"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_group_price_list_fk"
            columns: ["org_id", "default_price_list_id"]
            isOneToOne: false
            referencedRelation: "price_list"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      customer_group_credit_limit: {
        Row: {
          bypass_credit_limit_check: boolean
          company_id: string
          credit_limit: number
          id: string
          idx: number
          org_id: string
          parent_id: string
        }
        Insert: {
          bypass_credit_limit_check?: boolean
          company_id: string
          credit_limit?: number
          id?: string
          idx: number
          org_id: string
          parent_id: string
        }
        Update: {
          bypass_credit_limit_check?: boolean
          company_id?: string
          credit_limit?: number
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_group_credit_limit_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_group_credit_limit_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_group_credit_limit_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "customer_group"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      customer_group_party_account: {
        Row: {
          account_id: string | null
          company_id: string
          id: string
          idx: number
          org_id: string
          parent_id: string
        }
        Insert: {
          account_id?: string | null
          company_id: string
          id?: string
          idx: number
          org_id: string
          parent_id: string
        }
        Update: {
          account_id?: string | null
          company_id?: string
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_group_party_account_org_id_account_id_fkey"
            columns: ["org_id", "account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_group_party_account_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_group_party_account_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_group_party_account_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "customer_group"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      customer_party_account: {
        Row: {
          account_id: string | null
          company_id: string
          id: string
          idx: number
          org_id: string
          parent_id: string
        }
        Insert: {
          account_id?: string | null
          company_id: string
          id?: string
          idx: number
          org_id: string
          parent_id: string
        }
        Update: {
          account_id?: string | null
          company_id?: string
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_party_account_org_id_account_id_fkey"
            columns: ["org_id", "account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_party_account_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_party_account_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_party_account_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "customer"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      customer_sales_team: {
        Row: {
          allocated_percentage: number
          commission_rate: number | null
          id: string
          idx: number
          org_id: string
          parent_id: string
          sales_person_id: string
        }
        Insert: {
          allocated_percentage?: number
          commission_rate?: number | null
          id?: string
          idx: number
          org_id: string
          parent_id: string
          sales_person_id: string
        }
        Update: {
          allocated_percentage?: number
          commission_rate?: number | null
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
          sales_person_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_sales_team_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_sales_team_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "customer"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "customer_sales_team_org_id_sales_person_id_fkey"
            columns: ["org_id", "sales_person_id"]
            isOneToOne: false
            referencedRelation: "sales_person"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      department: {
        Row: {
          company_id: string | null
          created_at: string
          created_by: string | null
          department_name: string
          disabled: boolean
          id: string
          is_group: boolean
          name: string
          org_id: string
          parent_id: string | null
          path: unknown
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string
          created_by?: string | null
          department_name: string
          disabled?: boolean
          id?: string
          is_group?: boolean
          name: string
          org_id: string
          parent_id?: string | null
          path: unknown
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          company_id?: string | null
          created_at?: string
          created_by?: string | null
          department_name?: string
          disabled?: boolean
          id?: string
          is_group?: boolean
          name?: string
          org_id?: string
          parent_id?: string | null
          path?: unknown
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "department_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "department_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "department_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "department"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      designation: {
        Row: {
          created_at: string
          created_by: string | null
          description: string | null
          designation_name: string
          id: string
          org_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          description?: string | null
          designation_name: string
          id?: string
          org_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          description?: string | null
          designation_name?: string
          id?: string
          org_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "designation_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      doctype_meta: {
        Row: {
          allow_on_submit: string[]
          child_field: string | null
          doctype: string
          html_columns: string[]
          is_child: boolean
          is_single: boolean
          is_submittable: boolean
          is_tree: boolean
          module: string
          naming_series_default: string | null
          no_copy_fields: string[]
          parent_doctype: string | null
          table_name: string
          title_field: string | null
          user_permission_target: boolean
        }
        Insert: {
          allow_on_submit?: string[]
          child_field?: string | null
          doctype: string
          html_columns?: string[]
          is_child?: boolean
          is_single?: boolean
          is_submittable?: boolean
          is_tree?: boolean
          module: string
          naming_series_default?: string | null
          no_copy_fields?: string[]
          parent_doctype?: string | null
          table_name: string
          title_field?: string | null
          user_permission_target?: boolean
        }
        Update: {
          allow_on_submit?: string[]
          child_field?: string | null
          doctype?: string
          html_columns?: string[]
          is_child?: boolean
          is_single?: boolean
          is_submittable?: boolean
          is_tree?: boolean
          module?: string
          naming_series_default?: string | null
          no_copy_fields?: string[]
          parent_doctype?: string | null
          table_name?: string
          title_field?: string | null
          user_permission_target?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "doctype_meta_parent_doctype_fkey"
            columns: ["parent_doctype"]
            isOneToOne: false
            referencedRelation: "doctype_meta"
            referencedColumns: ["doctype"]
          },
        ]
      }
      email_account: {
        Row: {
          add_signature: boolean
          always_use_account_email_id_as_sender: boolean
          always_use_account_name_as_sender_name: boolean
          api_key_secret: string | null
          company_id: string | null
          created_at: string
          created_by: string | null
          default_outgoing: boolean
          email_account_name: string
          email_id: string
          enable_outgoing: boolean
          enabled: boolean
          footer: string | null
          has_api_key: boolean | null
          id: string
          org_id: string
          provider: string
          signature: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          add_signature?: boolean
          always_use_account_email_id_as_sender?: boolean
          always_use_account_name_as_sender_name?: boolean
          api_key_secret?: string | null
          company_id?: string | null
          created_at?: string
          created_by?: string | null
          default_outgoing?: boolean
          email_account_name: string
          email_id: string
          enable_outgoing?: boolean
          enabled?: boolean
          footer?: string | null
          has_api_key?: boolean | null
          id?: string
          org_id: string
          provider?: string
          signature?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          add_signature?: boolean
          always_use_account_email_id_as_sender?: boolean
          always_use_account_name_as_sender_name?: boolean
          api_key_secret?: string | null
          company_id?: string | null
          created_at?: string
          created_by?: string | null
          default_outgoing?: boolean
          email_account_name?: string
          email_id?: string
          enable_outgoing?: boolean
          enabled?: boolean
          footer?: string | null
          has_api_key?: boolean | null
          id?: string
          org_id?: string
          provider?: string
          signature?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "email_account_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "email_account_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      email_log: {
        Row: {
          cc: string[]
          created_at: string
          email_account_id: string | null
          error: string | null
          id: string
          org_id: string
          provider_message_id: string | null
          recipients: string[]
          reference_doctype: string | null
          reference_id: string | null
          sender: string
          sent_by: string | null
          status: string
          subject: string
        }
        Insert: {
          cc?: string[]
          created_at?: string
          email_account_id?: string | null
          error?: string | null
          id?: string
          org_id: string
          provider_message_id?: string | null
          recipients: string[]
          reference_doctype?: string | null
          reference_id?: string | null
          sender: string
          sent_by?: string | null
          status: string
          subject: string
        }
        Update: {
          cc?: string[]
          created_at?: string
          email_account_id?: string | null
          error?: string | null
          id?: string
          org_id?: string
          provider_message_id?: string | null
          recipients?: string[]
          reference_doctype?: string | null
          reference_id?: string | null
          sender?: string
          sent_by?: string | null
          status?: string
          subject?: string
        }
        Relationships: [
          {
            foreignKeyName: "email_log_email_account_id_fkey"
            columns: ["email_account_id"]
            isOneToOne: false
            referencedRelation: "email_account"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "email_log_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      email_template: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          name: string
          org_id: string
          response: string | null
          response_html: string | null
          subject: string
          updated_at: string
          updated_by: string | null
          use_html: boolean
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          org_id: string
          response?: string | null
          response_html?: string | null
          subject: string
          updated_at?: string
          updated_by?: string | null
          use_html?: boolean
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          org_id?: string
          response?: string | null
          response_html?: string | null
          subject?: string
          updated_at?: string
          updated_by?: string | null
          use_html?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "email_template_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      fiscal_year: {
        Row: {
          auto_created: boolean
          created_at: string
          created_by: string | null
          disabled: boolean
          id: string
          is_short_year: boolean
          org_id: string
          updated_at: string
          updated_by: string | null
          year: string
          year_end_date: string
          year_start_date: string
        }
        Insert: {
          auto_created?: boolean
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          is_short_year?: boolean
          org_id: string
          updated_at?: string
          updated_by?: string | null
          year: string
          year_end_date: string
          year_start_date: string
        }
        Update: {
          auto_created?: boolean
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          is_short_year?: boolean
          org_id?: string
          updated_at?: string
          updated_by?: string | null
          year?: string
          year_end_date?: string
          year_start_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "fiscal_year_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      fiscal_year_company: {
        Row: {
          company_id: string
          id: string
          idx: number
          org_id: string
          parent_id: string
        }
        Insert: {
          company_id: string
          id?: string
          idx: number
          org_id: string
          parent_id: string
        }
        Update: {
          company_id?: string
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fiscal_year_company_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "fiscal_year_company_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "fiscal_year"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      gl_entry: {
        Row: {
          account_currency: string | null
          account_id: string
          advance_voucher_id: string | null
          advance_voucher_type: string | null
          against: string | null
          against_voucher_id: string | null
          against_voucher_type: string | null
          company_id: string
          cost_center_id: string | null
          created_at: string
          credit: number
          credit_in_account_currency: number
          credit_in_transaction_currency: number
          debit: number
          debit_in_account_currency: number
          debit_in_transaction_currency: number
          due_date: string | null
          fiscal_year_id: string | null
          id: string
          is_advance: boolean
          is_cancelled: boolean
          is_opening: boolean
          is_system_generated: boolean
          org_id: string
          party_id: string | null
          party_type: string | null
          posting_date: string
          project_id: string | null
          remarks: string | null
          transaction_currency: string | null
          transaction_exchange_rate: number
          voucher_detail_id: string | null
          voucher_id: string
          voucher_no: string
          voucher_subtype: string | null
          voucher_type: string
        }
        Insert: {
          account_currency?: string | null
          account_id: string
          advance_voucher_id?: string | null
          advance_voucher_type?: string | null
          against?: string | null
          against_voucher_id?: string | null
          against_voucher_type?: string | null
          company_id: string
          cost_center_id?: string | null
          created_at?: string
          credit?: number
          credit_in_account_currency?: number
          credit_in_transaction_currency?: number
          debit?: number
          debit_in_account_currency?: number
          debit_in_transaction_currency?: number
          due_date?: string | null
          fiscal_year_id?: string | null
          id?: string
          is_advance?: boolean
          is_cancelled?: boolean
          is_opening?: boolean
          is_system_generated?: boolean
          org_id: string
          party_id?: string | null
          party_type?: string | null
          posting_date: string
          project_id?: string | null
          remarks?: string | null
          transaction_currency?: string | null
          transaction_exchange_rate?: number
          voucher_detail_id?: string | null
          voucher_id: string
          voucher_no: string
          voucher_subtype?: string | null
          voucher_type: string
        }
        Update: {
          account_currency?: string | null
          account_id?: string
          advance_voucher_id?: string | null
          advance_voucher_type?: string | null
          against?: string | null
          against_voucher_id?: string | null
          against_voucher_type?: string | null
          company_id?: string
          cost_center_id?: string | null
          created_at?: string
          credit?: number
          credit_in_account_currency?: number
          credit_in_transaction_currency?: number
          debit?: number
          debit_in_account_currency?: number
          debit_in_transaction_currency?: number
          due_date?: string | null
          fiscal_year_id?: string | null
          id?: string
          is_advance?: boolean
          is_cancelled?: boolean
          is_opening?: boolean
          is_system_generated?: boolean
          org_id?: string
          party_id?: string | null
          party_type?: string | null
          posting_date?: string
          project_id?: string | null
          remarks?: string | null
          transaction_currency?: string | null
          transaction_exchange_rate?: number
          voucher_detail_id?: string | null
          voucher_id?: string
          voucher_no?: string
          voucher_subtype?: string | null
          voucher_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "gl_entry_org_id_account_id_fkey"
            columns: ["org_id", "account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "gl_entry_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "gl_entry_org_id_cost_center_id_fkey"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "gl_entry_org_id_fiscal_year_id_fkey"
            columns: ["org_id", "fiscal_year_id"]
            isOneToOne: false
            referencedRelation: "fiscal_year"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "gl_entry_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      global_defaults: {
        Row: {
          country: string | null
          created_at: string
          created_by: string | null
          default_company_id: string | null
          default_currency: string | null
          default_distance_unit: string | null
          disable_in_words: boolean
          disable_rounded_total: boolean
          hide_currency_symbol: boolean
          id: string
          org_id: string
          updated_at: string
          updated_by: string | null
          use_posting_datetime_for_naming_documents: boolean
        }
        Insert: {
          country?: string | null
          created_at?: string
          created_by?: string | null
          default_company_id?: string | null
          default_currency?: string | null
          default_distance_unit?: string | null
          disable_in_words?: boolean
          disable_rounded_total?: boolean
          hide_currency_symbol?: boolean
          id?: string
          org_id: string
          updated_at?: string
          updated_by?: string | null
          use_posting_datetime_for_naming_documents?: boolean
        }
        Update: {
          country?: string | null
          created_at?: string
          created_by?: string | null
          default_company_id?: string | null
          default_currency?: string | null
          default_distance_unit?: string | null
          disable_in_words?: boolean
          disable_rounded_total?: boolean
          hide_currency_symbol?: boolean
          id?: string
          org_id?: string
          updated_at?: string
          updated_by?: string | null
          use_posting_datetime_for_naming_documents?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "global_defaults_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "coa_template_country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "global_defaults_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "global_defaults_default_company_id_fkey"
            columns: ["default_company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "global_defaults_default_currency_fkey"
            columns: ["default_currency"]
            isOneToOne: false
            referencedRelation: "currency"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "global_defaults_default_distance_unit_fkey"
            columns: ["default_distance_unit"]
            isOneToOne: false
            referencedRelation: "uom_template"
            referencedColumns: ["uom_name"]
          },
          {
            foreignKeyName: "global_defaults_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: true
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      holiday: {
        Row: {
          description: string
          holiday_date: string
          id: string
          idx: number
          is_half_day: boolean
          org_id: string
          parent_id: string
          weekly_off: boolean
        }
        Insert: {
          description: string
          holiday_date: string
          id?: string
          idx: number
          is_half_day?: boolean
          org_id: string
          parent_id: string
          weekly_off?: boolean
        }
        Update: {
          description?: string
          holiday_date?: string
          id?: string
          idx?: number
          is_half_day?: boolean
          org_id?: string
          parent_id?: string
          weekly_off?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "holiday_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "holiday_list"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      holiday_list: {
        Row: {
          color: string | null
          country: string | null
          created_at: string
          created_by: string | null
          from_date: string
          holiday_list_name: string
          id: string
          is_half_day: boolean
          org_id: string
          subdivision: string | null
          to_date: string
          total_holidays: number
          updated_at: string
          updated_by: string | null
          weekly_off: string | null
        }
        Insert: {
          color?: string | null
          country?: string | null
          created_at?: string
          created_by?: string | null
          from_date: string
          holiday_list_name: string
          id?: string
          is_half_day?: boolean
          org_id: string
          subdivision?: string | null
          to_date: string
          total_holidays?: number
          updated_at?: string
          updated_by?: string | null
          weekly_off?: string | null
        }
        Update: {
          color?: string | null
          country?: string | null
          created_at?: string
          created_by?: string | null
          from_date?: string
          holiday_list_name?: string
          id?: string
          is_half_day?: boolean
          org_id?: string
          subdivision?: string | null
          to_date?: string
          total_holidays?: number
          updated_at?: string
          updated_by?: string | null
          weekly_off?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "holiday_list_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "coa_template_country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "holiday_list_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "holiday_list_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      industry_type: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          industry: string
          org_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          industry: string
          org_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          industry?: string
          org_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "industry_type_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      invitations: {
        Row: {
          accepted_at: string | null
          accepted_by: string | null
          created_at: string
          created_by: string | null
          email: string
          expires_at: string
          id: string
          org_id: string
          revoked_at: string | null
          role_profile: string | null
          roles: string[]
          token: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          accepted_at?: string | null
          accepted_by?: string | null
          created_at?: string
          created_by?: string | null
          email: string
          expires_at?: string
          id?: string
          org_id: string
          revoked_at?: string | null
          role_profile?: string | null
          roles?: string[]
          token?: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          accepted_at?: string | null
          accepted_by?: string | null
          created_at?: string
          created_by?: string | null
          email?: string
          expires_at?: string
          id?: string
          org_id?: string
          revoked_at?: string | null
          role_profile?: string | null
          roles?: string[]
          token?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "invitations_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invitations_role_profile_fkey"
            columns: ["org_id", "role_profile"]
            isOneToOne: false
            referencedRelation: "role_profile"
            referencedColumns: ["org_id", "name"]
          },
        ]
      }
      item: {
        Row: {
          allow_negative_stock: boolean
          batch_number_series: string | null
          brand_id: string | null
          create_new_batch: boolean
          created_at: string
          created_by: string | null
          default_material_request_type: string
          delivered_by_supplier: boolean
          description: string | null
          disabled: boolean
          end_of_life: string
          grant_commission: boolean
          has_batch_no: boolean
          has_expiry_date: boolean
          has_serial_no: boolean
          has_variants: boolean
          id: string
          include_item_in_manufacturing: boolean
          is_fixed_asset: boolean
          is_purchase_item: boolean
          is_sales_item: boolean
          is_stock_item: boolean
          item_code: string
          item_group_id: string
          item_name: string
          last_purchase_rate: number | null
          lead_time_days: number | null
          max_discount: number | null
          min_order_qty: number
          name: string
          org_id: string
          over_billing_allowance: number | null
          over_delivery_receipt_allowance: number | null
          safety_stock: number | null
          serial_no_series: string | null
          shelf_life_in_days: number | null
          standard_rate: number | null
          stock_uom_id: string
          updated_at: string
          updated_by: string | null
          valuation_method: string | null
          valuation_rate: number | null
          weight_per_unit: number | null
          weight_uom_id: string | null
        }
        Insert: {
          allow_negative_stock?: boolean
          batch_number_series?: string | null
          brand_id?: string | null
          create_new_batch?: boolean
          created_at?: string
          created_by?: string | null
          default_material_request_type?: string
          delivered_by_supplier?: boolean
          description?: string | null
          disabled?: boolean
          end_of_life?: string
          grant_commission?: boolean
          has_batch_no?: boolean
          has_expiry_date?: boolean
          has_serial_no?: boolean
          has_variants?: boolean
          id?: string
          include_item_in_manufacturing?: boolean
          is_fixed_asset?: boolean
          is_purchase_item?: boolean
          is_sales_item?: boolean
          is_stock_item?: boolean
          item_code: string
          item_group_id: string
          item_name: string
          last_purchase_rate?: number | null
          lead_time_days?: number | null
          max_discount?: number | null
          min_order_qty?: number
          name: string
          org_id: string
          over_billing_allowance?: number | null
          over_delivery_receipt_allowance?: number | null
          safety_stock?: number | null
          serial_no_series?: string | null
          shelf_life_in_days?: number | null
          standard_rate?: number | null
          stock_uom_id: string
          updated_at?: string
          updated_by?: string | null
          valuation_method?: string | null
          valuation_rate?: number | null
          weight_per_unit?: number | null
          weight_uom_id?: string | null
        }
        Update: {
          allow_negative_stock?: boolean
          batch_number_series?: string | null
          brand_id?: string | null
          create_new_batch?: boolean
          created_at?: string
          created_by?: string | null
          default_material_request_type?: string
          delivered_by_supplier?: boolean
          description?: string | null
          disabled?: boolean
          end_of_life?: string
          grant_commission?: boolean
          has_batch_no?: boolean
          has_expiry_date?: boolean
          has_serial_no?: boolean
          has_variants?: boolean
          id?: string
          include_item_in_manufacturing?: boolean
          is_fixed_asset?: boolean
          is_purchase_item?: boolean
          is_sales_item?: boolean
          is_stock_item?: boolean
          item_code?: string
          item_group_id?: string
          item_name?: string
          last_purchase_rate?: number | null
          lead_time_days?: number | null
          max_discount?: number | null
          min_order_qty?: number
          name?: string
          org_id?: string
          over_billing_allowance?: number | null
          over_delivery_receipt_allowance?: number | null
          safety_stock?: number | null
          serial_no_series?: string | null
          shelf_life_in_days?: number | null
          standard_rate?: number | null
          stock_uom_id?: string
          updated_at?: string
          updated_by?: string | null
          valuation_method?: string | null
          valuation_rate?: number | null
          weight_per_unit?: number | null
          weight_uom_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "item_org_id_brand_id_fkey"
            columns: ["org_id", "brand_id"]
            isOneToOne: false
            referencedRelation: "brand"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_org_id_item_group_id_fkey"
            columns: ["org_id", "item_group_id"]
            isOneToOne: false
            referencedRelation: "item_group"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_org_id_stock_uom_id_fkey"
            columns: ["org_id", "stock_uom_id"]
            isOneToOne: false
            referencedRelation: "uom"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_org_id_weight_uom_id_fkey"
            columns: ["org_id", "weight_uom_id"]
            isOneToOne: false
            referencedRelation: "uom"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      item_barcode: {
        Row: {
          barcode: string
          id: string
          idx: number
          org_id: string
          parent_id: string
        }
        Insert: {
          barcode: string
          id?: string
          idx: number
          org_id: string
          parent_id: string
        }
        Update: {
          barcode?: string
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "item_barcode_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_barcode_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      item_default: {
        Row: {
          buying_cost_center_id: string | null
          company_id: string
          default_price_list_id: string | null
          default_supplier_id: string | null
          default_warehouse_id: string | null
          expense_account_id: string | null
          id: string
          idx: number
          income_account_id: string | null
          org_id: string
          parent_id: string
          selling_cost_center_id: string | null
        }
        Insert: {
          buying_cost_center_id?: string | null
          company_id: string
          default_price_list_id?: string | null
          default_supplier_id?: string | null
          default_warehouse_id?: string | null
          expense_account_id?: string | null
          id?: string
          idx: number
          income_account_id?: string | null
          org_id: string
          parent_id: string
          selling_cost_center_id?: string | null
        }
        Update: {
          buying_cost_center_id?: string | null
          company_id?: string
          default_price_list_id?: string | null
          default_supplier_id?: string | null
          default_warehouse_id?: string | null
          expense_account_id?: string | null
          id?: string
          idx?: number
          income_account_id?: string | null
          org_id?: string
          parent_id?: string
          selling_cost_center_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "item_default_org_id_buying_cost_center_id_fkey"
            columns: ["org_id", "buying_cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_default_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_default_org_id_default_price_list_id_fkey"
            columns: ["org_id", "default_price_list_id"]
            isOneToOne: false
            referencedRelation: "price_list"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_default_org_id_default_supplier_id_fkey"
            columns: ["org_id", "default_supplier_id"]
            isOneToOne: false
            referencedRelation: "supplier"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_default_org_id_default_warehouse_id_fkey"
            columns: ["org_id", "default_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_default_org_id_expense_account_id_fkey"
            columns: ["org_id", "expense_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_default_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_default_org_id_income_account_id_fkey"
            columns: ["org_id", "income_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_default_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_default_org_id_selling_cost_center_id_fkey"
            columns: ["org_id", "selling_cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      item_group: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          is_group: boolean
          item_group_name: string
          org_id: string
          parent_id: string | null
          path: unknown
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_group?: boolean
          item_group_name: string
          org_id: string
          parent_id?: string | null
          path: unknown
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_group?: boolean
          item_group_name?: string
          org_id?: string
          parent_id?: string | null
          path?: unknown
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "item_group_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_group_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "item_group"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      item_group_default: {
        Row: {
          buying_cost_center_id: string | null
          company_id: string
          default_price_list_id: string | null
          default_supplier_id: string | null
          default_warehouse_id: string | null
          expense_account_id: string | null
          id: string
          idx: number
          income_account_id: string | null
          org_id: string
          parent_id: string
          selling_cost_center_id: string | null
        }
        Insert: {
          buying_cost_center_id?: string | null
          company_id: string
          default_price_list_id?: string | null
          default_supplier_id?: string | null
          default_warehouse_id?: string | null
          expense_account_id?: string | null
          id?: string
          idx: number
          income_account_id?: string | null
          org_id: string
          parent_id: string
          selling_cost_center_id?: string | null
        }
        Update: {
          buying_cost_center_id?: string | null
          company_id?: string
          default_price_list_id?: string | null
          default_supplier_id?: string | null
          default_warehouse_id?: string | null
          expense_account_id?: string | null
          id?: string
          idx?: number
          income_account_id?: string | null
          org_id?: string
          parent_id?: string
          selling_cost_center_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "item_group_default_org_id_buying_cost_center_id_fkey"
            columns: ["org_id", "buying_cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_group_default_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_group_default_org_id_default_price_list_id_fkey"
            columns: ["org_id", "default_price_list_id"]
            isOneToOne: false
            referencedRelation: "price_list"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_group_default_org_id_default_supplier_id_fkey"
            columns: ["org_id", "default_supplier_id"]
            isOneToOne: false
            referencedRelation: "supplier"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_group_default_org_id_default_warehouse_id_fkey"
            columns: ["org_id", "default_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_group_default_org_id_expense_account_id_fkey"
            columns: ["org_id", "expense_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_group_default_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_group_default_org_id_income_account_id_fkey"
            columns: ["org_id", "income_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_group_default_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "item_group"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_group_default_org_id_selling_cost_center_id_fkey"
            columns: ["org_id", "selling_cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      item_group_tax: {
        Row: {
          id: string
          idx: number
          item_tax_template_id: string | null
          maximum_net_rate: number | null
          minimum_net_rate: number | null
          org_id: string
          parent_id: string
          tax_category_id: string | null
          valid_from: string | null
        }
        Insert: {
          id?: string
          idx: number
          item_tax_template_id?: string | null
          maximum_net_rate?: number | null
          minimum_net_rate?: number | null
          org_id: string
          parent_id: string
          tax_category_id?: string | null
          valid_from?: string | null
        }
        Update: {
          id?: string
          idx?: number
          item_tax_template_id?: string | null
          maximum_net_rate?: number | null
          minimum_net_rate?: number | null
          org_id?: string
          parent_id?: string
          tax_category_id?: string | null
          valid_from?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "item_group_tax_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_group_tax_org_id_item_tax_template_id_fkey"
            columns: ["org_id", "item_tax_template_id"]
            isOneToOne: false
            referencedRelation: "item_tax_template"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_group_tax_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "item_group"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_group_tax_org_id_tax_category_id_fkey"
            columns: ["org_id", "tax_category_id"]
            isOneToOne: false
            referencedRelation: "tax_category"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      item_price: {
        Row: {
          buying: boolean
          created_at: string
          created_by: string | null
          currency: string
          customer_id: string | null
          id: string
          item_id: string
          item_name: string
          lead_time_days: number | null
          name: string
          org_id: string
          packing_unit: number
          price_list_id: string
          price_list_rate: number
          selling: boolean
          supplier_id: string | null
          uom_id: string
          updated_at: string
          updated_by: string | null
          valid_from: string
          valid_upto: string | null
        }
        Insert: {
          buying?: boolean
          created_at?: string
          created_by?: string | null
          currency: string
          customer_id?: string | null
          id?: string
          item_id: string
          item_name: string
          lead_time_days?: number | null
          name: string
          org_id: string
          packing_unit?: number
          price_list_id: string
          price_list_rate: number
          selling?: boolean
          supplier_id?: string | null
          uom_id: string
          updated_at?: string
          updated_by?: string | null
          valid_from?: string
          valid_upto?: string | null
        }
        Update: {
          buying?: boolean
          created_at?: string
          created_by?: string | null
          currency?: string
          customer_id?: string | null
          id?: string
          item_id?: string
          item_name?: string
          lead_time_days?: number | null
          name?: string
          org_id?: string
          packing_unit?: number
          price_list_id?: string
          price_list_rate?: number
          selling?: boolean
          supplier_id?: string | null
          uom_id?: string
          updated_at?: string
          updated_by?: string | null
          valid_from?: string
          valid_upto?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "item_price_currency_fkey"
            columns: ["currency"]
            isOneToOne: false
            referencedRelation: "currency"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "item_price_org_id_customer_id_fkey"
            columns: ["org_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "customer"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_price_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_price_org_id_item_id_fkey"
            columns: ["org_id", "item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_price_org_id_price_list_id_fkey"
            columns: ["org_id", "price_list_id"]
            isOneToOne: false
            referencedRelation: "price_list"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_price_org_id_supplier_id_fkey"
            columns: ["org_id", "supplier_id"]
            isOneToOne: false
            referencedRelation: "supplier"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_price_org_id_uom_id_fkey"
            columns: ["org_id", "uom_id"]
            isOneToOne: false
            referencedRelation: "uom"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      item_reorder: {
        Row: {
          id: string
          idx: number
          material_request_type: string
          org_id: string
          parent_id: string
          warehouse_group_id: string | null
          warehouse_id: string | null
          warehouse_reorder_level: number
          warehouse_reorder_qty: number
        }
        Insert: {
          id?: string
          idx: number
          material_request_type?: string
          org_id: string
          parent_id: string
          warehouse_group_id?: string | null
          warehouse_id?: string | null
          warehouse_reorder_level?: number
          warehouse_reorder_qty?: number
        }
        Update: {
          id?: string
          idx?: number
          material_request_type?: string
          org_id?: string
          parent_id?: string
          warehouse_group_id?: string | null
          warehouse_id?: string | null
          warehouse_reorder_level?: number
          warehouse_reorder_qty?: number
        }
        Relationships: [
          {
            foreignKeyName: "item_reorder_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_reorder_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_reorder_org_id_warehouse_group_id_fkey"
            columns: ["org_id", "warehouse_group_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_reorder_org_id_warehouse_id_fkey"
            columns: ["org_id", "warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      item_supplier: {
        Row: {
          id: string
          idx: number
          org_id: string
          parent_id: string
          supplier_id: string
          supplier_part_no: string | null
        }
        Insert: {
          id?: string
          idx: number
          org_id: string
          parent_id: string
          supplier_id: string
          supplier_part_no?: string | null
        }
        Update: {
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
          supplier_id?: string
          supplier_part_no?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "item_supplier_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_supplier_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_supplier_org_id_supplier_id_fkey"
            columns: ["org_id", "supplier_id"]
            isOneToOne: false
            referencedRelation: "supplier"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      item_tax: {
        Row: {
          id: string
          idx: number
          item_tax_template_id: string | null
          maximum_net_rate: number | null
          minimum_net_rate: number | null
          org_id: string
          parent_id: string
          tax_category_id: string | null
          valid_from: string | null
        }
        Insert: {
          id?: string
          idx: number
          item_tax_template_id?: string | null
          maximum_net_rate?: number | null
          minimum_net_rate?: number | null
          org_id: string
          parent_id: string
          tax_category_id?: string | null
          valid_from?: string | null
        }
        Update: {
          id?: string
          idx?: number
          item_tax_template_id?: string | null
          maximum_net_rate?: number | null
          minimum_net_rate?: number | null
          org_id?: string
          parent_id?: string
          tax_category_id?: string | null
          valid_from?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "item_tax_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_tax_org_id_item_tax_template_id_fkey"
            columns: ["org_id", "item_tax_template_id"]
            isOneToOne: false
            referencedRelation: "item_tax_template"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_tax_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_tax_org_id_tax_category_id_fkey"
            columns: ["org_id", "tax_category_id"]
            isOneToOne: false
            referencedRelation: "tax_category"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      item_tax_template: {
        Row: {
          company_id: string
          created_at: string
          created_by: string | null
          disabled: boolean
          id: string
          name: string
          org_id: string
          title: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          company_id: string
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          name: string
          org_id: string
          title: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          company_id?: string
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          name?: string
          org_id?: string
          title?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "item_tax_template_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_tax_template_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      item_tax_template_detail: {
        Row: {
          created_at: string
          id: string
          idx: number
          not_applicable: boolean
          org_id: string
          parent_id: string
          tax_rate: number | null
          tax_type_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          idx: number
          not_applicable?: boolean
          org_id: string
          parent_id: string
          tax_rate?: number | null
          tax_type_id: string
        }
        Update: {
          created_at?: string
          id?: string
          idx?: number
          not_applicable?: boolean
          org_id?: string
          parent_id?: string
          tax_rate?: number | null
          tax_type_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "item_tax_template_detail_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "item_tax_template"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_tax_template_detail_org_id_tax_type_id_fkey"
            columns: ["org_id", "tax_type_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      item_uom: {
        Row: {
          conversion_factor: number
          id: string
          idx: number
          org_id: string
          parent_id: string
          uom_id: string
        }
        Insert: {
          conversion_factor: number
          id?: string
          idx: number
          org_id: string
          parent_id: string
          uom_id: string
        }
        Update: {
          conversion_factor?: number
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
          uom_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "item_uom_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_uom_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "item_uom_org_id_uom_id_fkey"
            columns: ["org_id", "uom_id"]
            isOneToOne: false
            referencedRelation: "uom"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      journal_entry: {
        Row: {
          amended_from: string | null
          bill_date: string | null
          bill_no: string | null
          cheque_date: string | null
          cheque_no: string | null
          clearance_date: string | null
          company_id: string
          created_at: string
          created_by: string | null
          custom_remark: boolean
          difference: number
          docstatus: number
          due_date: string | null
          id: string
          is_opening: string
          letter_head_id: string | null
          mode_of_payment_id: string | null
          multi_currency: boolean
          name: string
          naming_series: string
          org_id: string
          pay_to_recd_from: string | null
          posting_date: string
          print_heading_id: string | null
          reversal_of: string | null
          stock_entry_id: string | null
          title: string | null
          total_credit: number
          total_debit: number
          updated_at: string
          updated_by: string | null
          user_remark: string | null
          voucher_type: string
          write_off_amount: number
          write_off_based_on: string
        }
        Insert: {
          amended_from?: string | null
          bill_date?: string | null
          bill_no?: string | null
          cheque_date?: string | null
          cheque_no?: string | null
          clearance_date?: string | null
          company_id: string
          created_at?: string
          created_by?: string | null
          custom_remark?: boolean
          difference?: number
          docstatus?: number
          due_date?: string | null
          id?: string
          is_opening?: string
          letter_head_id?: string | null
          mode_of_payment_id?: string | null
          multi_currency?: boolean
          name: string
          naming_series?: string
          org_id: string
          pay_to_recd_from?: string | null
          posting_date?: string
          print_heading_id?: string | null
          reversal_of?: string | null
          stock_entry_id?: string | null
          title?: string | null
          total_credit?: number
          total_debit?: number
          updated_at?: string
          updated_by?: string | null
          user_remark?: string | null
          voucher_type?: string
          write_off_amount?: number
          write_off_based_on?: string
        }
        Update: {
          amended_from?: string | null
          bill_date?: string | null
          bill_no?: string | null
          cheque_date?: string | null
          cheque_no?: string | null
          clearance_date?: string | null
          company_id?: string
          created_at?: string
          created_by?: string | null
          custom_remark?: boolean
          difference?: number
          docstatus?: number
          due_date?: string | null
          id?: string
          is_opening?: string
          letter_head_id?: string | null
          mode_of_payment_id?: string | null
          multi_currency?: boolean
          name?: string
          naming_series?: string
          org_id?: string
          pay_to_recd_from?: string | null
          posting_date?: string
          print_heading_id?: string | null
          reversal_of?: string | null
          stock_entry_id?: string | null
          title?: string | null
          total_credit?: number
          total_debit?: number
          updated_at?: string
          updated_by?: string | null
          user_remark?: string | null
          voucher_type?: string
          write_off_amount?: number
          write_off_based_on?: string
        }
        Relationships: [
          {
            foreignKeyName: "journal_entry_org_id_amended_from_fkey"
            columns: ["org_id", "amended_from"]
            isOneToOne: false
            referencedRelation: "journal_entry"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "journal_entry_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "journal_entry_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "journal_entry_org_id_letter_head_id_fkey"
            columns: ["org_id", "letter_head_id"]
            isOneToOne: false
            referencedRelation: "letter_head"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "journal_entry_org_id_mode_of_payment_id_fkey"
            columns: ["org_id", "mode_of_payment_id"]
            isOneToOne: false
            referencedRelation: "mode_of_payment"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "journal_entry_org_id_print_heading_id_fkey"
            columns: ["org_id", "print_heading_id"]
            isOneToOne: false
            referencedRelation: "print_heading"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "journal_entry_org_id_reversal_of_fkey"
            columns: ["org_id", "reversal_of"]
            isOneToOne: false
            referencedRelation: "journal_entry"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      journal_entry_account: {
        Row: {
          account_currency: string | null
          account_id: string
          account_type: string | null
          advance_voucher_id: string | null
          advance_voucher_type: string | null
          against_account: string | null
          cost_center_id: string | null
          credit: number
          credit_in_account_currency: number
          debit: number
          debit_in_account_currency: number
          exchange_rate: number
          id: string
          idx: number
          is_advance: string
          org_id: string
          parent_id: string
          party_id: string | null
          party_type: string | null
          reference_due_date: string | null
          reference_id: string | null
          reference_type: string | null
          user_remark: string | null
        }
        Insert: {
          account_currency?: string | null
          account_id: string
          account_type?: string | null
          advance_voucher_id?: string | null
          advance_voucher_type?: string | null
          against_account?: string | null
          cost_center_id?: string | null
          credit?: number
          credit_in_account_currency?: number
          debit?: number
          debit_in_account_currency?: number
          exchange_rate?: number
          id?: string
          idx: number
          is_advance?: string
          org_id: string
          parent_id: string
          party_id?: string | null
          party_type?: string | null
          reference_due_date?: string | null
          reference_id?: string | null
          reference_type?: string | null
          user_remark?: string | null
        }
        Update: {
          account_currency?: string | null
          account_id?: string
          account_type?: string | null
          advance_voucher_id?: string | null
          advance_voucher_type?: string | null
          against_account?: string | null
          cost_center_id?: string | null
          credit?: number
          credit_in_account_currency?: number
          debit?: number
          debit_in_account_currency?: number
          exchange_rate?: number
          id?: string
          idx?: number
          is_advance?: string
          org_id?: string
          parent_id?: string
          party_id?: string | null
          party_type?: string | null
          reference_due_date?: string | null
          reference_id?: string | null
          reference_type?: string | null
          user_remark?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "journal_entry_account_org_id_account_id_fkey"
            columns: ["org_id", "account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "journal_entry_account_org_id_cost_center_id_fkey"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "journal_entry_account_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "journal_entry"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      letter_head: {
        Row: {
          align: string
          content: string | null
          created_at: string
          created_by: string | null
          disabled: boolean
          footer: string | null
          footer_align: string
          footer_image: string | null
          footer_image_height: number | null
          footer_image_width: number | null
          footer_source: string
          id: string
          image: string | null
          image_height: number | null
          image_width: number | null
          is_default: boolean
          letter_head_name: string
          org_id: string
          source: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          align?: string
          content?: string | null
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          footer?: string | null
          footer_align?: string
          footer_image?: string | null
          footer_image_height?: number | null
          footer_image_width?: number | null
          footer_source?: string
          id?: string
          image?: string | null
          image_height?: number | null
          image_width?: number | null
          is_default?: boolean
          letter_head_name: string
          org_id: string
          source?: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          align?: string
          content?: string | null
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          footer?: string | null
          footer_align?: string
          footer_image?: string | null
          footer_image_height?: number | null
          footer_image_width?: number | null
          footer_source?: string
          id?: string
          image?: string | null
          image_height?: number | null
          image_width?: number | null
          is_default?: boolean
          letter_head_name?: string
          org_id?: string
          source?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "letter_head_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      material_request: {
        Row: {
          amended_from: string | null
          company_id: string
          created_at: string
          created_by: string | null
          customer_id: string | null
          docstatus: number
          id: string
          material_request_type: string
          name: string
          naming_series: string
          org_id: string
          per_ordered: number
          per_received: number
          schedule_date: string | null
          set_from_warehouse_id: string | null
          set_warehouse_id: string | null
          status: string
          title: string | null
          transaction_date: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          amended_from?: string | null
          company_id: string
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          docstatus?: number
          id?: string
          material_request_type: string
          name: string
          naming_series?: string
          org_id: string
          per_ordered?: number
          per_received?: number
          schedule_date?: string | null
          set_from_warehouse_id?: string | null
          set_warehouse_id?: string | null
          status?: string
          title?: string | null
          transaction_date?: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          amended_from?: string | null
          company_id?: string
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          docstatus?: number
          id?: string
          material_request_type?: string
          name?: string
          naming_series?: string
          org_id?: string
          per_ordered?: number
          per_received?: number
          schedule_date?: string | null
          set_from_warehouse_id?: string | null
          set_warehouse_id?: string | null
          status?: string
          title?: string | null
          transaction_date?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "material_request_org_id_amended_from_fkey"
            columns: ["org_id", "amended_from"]
            isOneToOne: false
            referencedRelation: "material_request"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "material_request_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "material_request_org_id_customer_id_fkey"
            columns: ["org_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "customer"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "material_request_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "material_request_org_id_set_from_warehouse_id_fkey"
            columns: ["org_id", "set_from_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "material_request_org_id_set_warehouse_id_fkey"
            columns: ["org_id", "set_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      material_request_item: {
        Row: {
          amount: number
          conversion_factor: number
          cost_center_id: string | null
          from_warehouse_id: string | null
          id: string
          idx: number
          item_id: string
          ordered_qty: number
          org_id: string
          parent_id: string
          project: string | null
          qty: number
          rate: number
          received_qty: number
          schedule_date: string | null
          stock_qty: number
          stock_uom_id: string | null
          uom_id: string | null
          warehouse_id: string | null
        }
        Insert: {
          amount?: number
          conversion_factor?: number
          cost_center_id?: string | null
          from_warehouse_id?: string | null
          id?: string
          idx: number
          item_id: string
          ordered_qty?: number
          org_id: string
          parent_id: string
          project?: string | null
          qty: number
          rate?: number
          received_qty?: number
          schedule_date?: string | null
          stock_qty?: number
          stock_uom_id?: string | null
          uom_id?: string | null
          warehouse_id?: string | null
        }
        Update: {
          amount?: number
          conversion_factor?: number
          cost_center_id?: string | null
          from_warehouse_id?: string | null
          id?: string
          idx?: number
          item_id?: string
          ordered_qty?: number
          org_id?: string
          parent_id?: string
          project?: string | null
          qty?: number
          rate?: number
          received_qty?: number
          schedule_date?: string | null
          stock_qty?: number
          stock_uom_id?: string | null
          uom_id?: string | null
          warehouse_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "material_request_item_org_id_cost_center_id_fkey"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "material_request_item_org_id_from_warehouse_id_fkey"
            columns: ["org_id", "from_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "material_request_item_org_id_item_id_fkey"
            columns: ["org_id", "item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "material_request_item_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "material_request"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "material_request_item_org_id_stock_uom_id_fkey"
            columns: ["org_id", "stock_uom_id"]
            isOneToOne: false
            referencedRelation: "uom"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "material_request_item_org_id_uom_id_fkey"
            columns: ["org_id", "uom_id"]
            isOneToOne: false
            referencedRelation: "uom"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "material_request_item_org_id_warehouse_id_fkey"
            columns: ["org_id", "warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      mode_of_payment: {
        Row: {
          created_at: string
          created_by: string | null
          enabled: boolean
          id: string
          mode_of_payment: string
          name: string
          org_id: string
          type: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          enabled?: boolean
          id?: string
          mode_of_payment: string
          name: string
          org_id: string
          type?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          enabled?: boolean
          id?: string
          mode_of_payment?: string
          name?: string
          org_id?: string
          type?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "mode_of_payment_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      mode_of_payment_account: {
        Row: {
          company_id: string
          default_account_id: string | null
          id: string
          idx: number
          org_id: string
          parent_id: string
        }
        Insert: {
          company_id: string
          default_account_id?: string | null
          id?: string
          idx: number
          org_id: string
          parent_id: string
        }
        Update: {
          company_id?: string
          default_account_id?: string | null
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "mode_of_payment_account_account_fk"
            columns: ["org_id", "default_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "mode_of_payment_account_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "mode_of_payment_account_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "mode_of_payment"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      naming_series: {
        Row: {
          created_at: string
          created_by: string | null
          current: number
          id: string
          org_id: string
          prefix: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          current?: number
          id?: string
          org_id: string
          prefix: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          current?: number
          id?: string
          org_id?: string
          prefix?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "naming_series_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      onboarding_progress: {
        Row: {
          completed_at: string | null
          created_at: string
          created_by: string | null
          idx: number
          org_id: string
          skipped_at: string | null
          step: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          completed_at?: string | null
          created_at?: string
          created_by?: string | null
          idx: number
          org_id: string
          skipped_at?: string | null
          step: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          completed_at?: string | null
          created_at?: string
          created_by?: string | null
          idx?: number
          org_id?: string
          skipped_at?: string | null
          step?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "onboarding_progress_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      org_currency: {
        Row: {
          code: string
          created_at: string
          enabled: boolean
          org_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          code: string
          created_at?: string
          enabled?: boolean
          org_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          enabled?: boolean
          org_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "org_currency_code_fkey"
            columns: ["code"]
            isOneToOne: false
            referencedRelation: "currency"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "org_currency_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      org_members: {
        Row: {
          created_at: string
          created_by: string | null
          is_owner: boolean
          org_id: string
          role_profile: string | null
          roles: string[]
          status: string
          updated_at: string
          updated_by: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          is_owner?: boolean
          org_id: string
          role_profile?: string | null
          roles?: string[]
          status?: string
          updated_at?: string
          updated_by?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          is_owner?: boolean
          org_id?: string
          role_profile?: string | null
          roles?: string[]
          status?: string
          updated_at?: string
          updated_by?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "org_members_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "org_members_role_profile_fkey"
            columns: ["org_id", "role_profile"]
            isOneToOne: false
            referencedRelation: "role_profile"
            referencedColumns: ["org_id", "name"]
          },
        ]
      }
      organizations: {
        Row: {
          country: string | null
          created_at: string
          created_by: string | null
          default_currency: string | null
          id: string
          language: string
          name: string
          onboarding_dismissed_at: string | null
          plan: string
          provisioned_at: string | null
          slug: string
          status: string
          time_zone: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          country?: string | null
          created_at?: string
          created_by?: string | null
          default_currency?: string | null
          id?: string
          language?: string
          name: string
          onboarding_dismissed_at?: string | null
          plan?: string
          provisioned_at?: string | null
          slug: string
          status?: string
          time_zone?: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          country?: string | null
          created_at?: string
          created_by?: string | null
          default_currency?: string | null
          id?: string
          language?: string
          name?: string
          onboarding_dismissed_at?: string | null
          plan?: string
          provisioned_at?: string | null
          slug?: string
          status?: string
          time_zone?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "organizations_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "coa_template_country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "organizations_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "organizations_default_currency_fkey"
            columns: ["default_currency"]
            isOneToOne: false
            referencedRelation: "currency"
            referencedColumns: ["code"]
          },
        ]
      }
      party_type: {
        Row: {
          account_type: string
          created_at: string
          created_by: string | null
          id: string
          name: string
          org_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          account_type: string
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          org_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          account_type?: string
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          org_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "party_type_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_entry: {
        Row: {
          amended_from: string | null
          base_paid_amount: number
          base_received_amount: number
          base_total_allocated_amount: number
          clearance_date: string | null
          company_id: string
          contact_email: string | null
          contact_person_id: string | null
          cost_center_id: string | null
          created_at: string
          created_by: string | null
          custom_remarks: boolean
          difference_amount: number
          docstatus: number
          id: string
          is_opening: string
          mode_of_payment_id: string | null
          name: string
          naming_series: string
          org_id: string
          paid_amount: number
          paid_from_account_balance: number
          paid_from_account_currency: string | null
          paid_from_account_id: string
          paid_from_account_type: string | null
          paid_to_account_balance: number
          paid_to_account_currency: string | null
          paid_to_account_id: string
          paid_to_account_type: string | null
          party_balance: number
          party_id: string | null
          party_name: string | null
          party_type: string | null
          payment_type: string
          posting_date: string
          received_amount: number
          reference_date: string | null
          reference_no: string | null
          remarks: string | null
          source_exchange_rate: number
          status: string
          target_exchange_rate: number
          title: string | null
          total_allocated_amount: number
          unallocated_amount: number
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          amended_from?: string | null
          base_paid_amount?: number
          base_received_amount?: number
          base_total_allocated_amount?: number
          clearance_date?: string | null
          company_id: string
          contact_email?: string | null
          contact_person_id?: string | null
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          custom_remarks?: boolean
          difference_amount?: number
          docstatus?: number
          id?: string
          is_opening?: string
          mode_of_payment_id?: string | null
          name: string
          naming_series?: string
          org_id: string
          paid_amount?: number
          paid_from_account_balance?: number
          paid_from_account_currency?: string | null
          paid_from_account_id: string
          paid_from_account_type?: string | null
          paid_to_account_balance?: number
          paid_to_account_currency?: string | null
          paid_to_account_id: string
          paid_to_account_type?: string | null
          party_balance?: number
          party_id?: string | null
          party_name?: string | null
          party_type?: string | null
          payment_type?: string
          posting_date?: string
          received_amount?: number
          reference_date?: string | null
          reference_no?: string | null
          remarks?: string | null
          source_exchange_rate?: number
          status?: string
          target_exchange_rate?: number
          title?: string | null
          total_allocated_amount?: number
          unallocated_amount?: number
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          amended_from?: string | null
          base_paid_amount?: number
          base_received_amount?: number
          base_total_allocated_amount?: number
          clearance_date?: string | null
          company_id?: string
          contact_email?: string | null
          contact_person_id?: string | null
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          custom_remarks?: boolean
          difference_amount?: number
          docstatus?: number
          id?: string
          is_opening?: string
          mode_of_payment_id?: string | null
          name?: string
          naming_series?: string
          org_id?: string
          paid_amount?: number
          paid_from_account_balance?: number
          paid_from_account_currency?: string | null
          paid_from_account_id?: string
          paid_from_account_type?: string | null
          paid_to_account_balance?: number
          paid_to_account_currency?: string | null
          paid_to_account_id?: string
          paid_to_account_type?: string | null
          party_balance?: number
          party_id?: string | null
          party_name?: string | null
          party_type?: string | null
          payment_type?: string
          posting_date?: string
          received_amount?: number
          reference_date?: string | null
          reference_no?: string | null
          remarks?: string | null
          source_exchange_rate?: number
          status?: string
          target_exchange_rate?: number
          title?: string | null
          total_allocated_amount?: number
          unallocated_amount?: number
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "payment_entry_org_id_amended_from_fkey"
            columns: ["org_id", "amended_from"]
            isOneToOne: false
            referencedRelation: "payment_entry"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_entry_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_entry_org_id_contact_person_id_fkey"
            columns: ["org_id", "contact_person_id"]
            isOneToOne: false
            referencedRelation: "contact"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_entry_org_id_cost_center_id_fkey"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_entry_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_entry_org_id_mode_of_payment_id_fkey"
            columns: ["org_id", "mode_of_payment_id"]
            isOneToOne: false
            referencedRelation: "mode_of_payment"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_entry_org_id_paid_from_account_id_fkey"
            columns: ["org_id", "paid_from_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_entry_org_id_paid_to_account_id_fkey"
            columns: ["org_id", "paid_to_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      payment_entry_deduction: {
        Row: {
          account_id: string
          amount: number
          cost_center_id: string
          description: string | null
          id: string
          idx: number
          is_exchange_gain_loss: boolean
          org_id: string
          parent_id: string
        }
        Insert: {
          account_id: string
          amount?: number
          cost_center_id: string
          description?: string | null
          id?: string
          idx: number
          is_exchange_gain_loss?: boolean
          org_id: string
          parent_id: string
        }
        Update: {
          account_id?: string
          amount?: number
          cost_center_id?: string
          description?: string | null
          id?: string
          idx?: number
          is_exchange_gain_loss?: boolean
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_entry_deduction_org_id_account_id_fkey"
            columns: ["org_id", "account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_entry_deduction_org_id_cost_center_id_fkey"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_entry_deduction_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "payment_entry"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      payment_entry_reference: {
        Row: {
          account_id: string | null
          account_type: string | null
          advance_voucher_type: string | null
          allocated_amount: number
          bill_no: string | null
          due_date: string | null
          exchange_gain_loss: number
          exchange_rate: number
          id: string
          idx: number
          org_id: string
          outstanding_amount: number
          parent_id: string
          payment_term_id: string | null
          payment_term_outstanding: number
          payment_type: string | null
          reference_doctype: string
          reference_id: string
          total_amount: number
        }
        Insert: {
          account_id?: string | null
          account_type?: string | null
          advance_voucher_type?: string | null
          allocated_amount?: number
          bill_no?: string | null
          due_date?: string | null
          exchange_gain_loss?: number
          exchange_rate?: number
          id?: string
          idx: number
          org_id: string
          outstanding_amount?: number
          parent_id: string
          payment_term_id?: string | null
          payment_term_outstanding?: number
          payment_type?: string | null
          reference_doctype: string
          reference_id: string
          total_amount?: number
        }
        Update: {
          account_id?: string | null
          account_type?: string | null
          advance_voucher_type?: string | null
          allocated_amount?: number
          bill_no?: string | null
          due_date?: string | null
          exchange_gain_loss?: number
          exchange_rate?: number
          id?: string
          idx?: number
          org_id?: string
          outstanding_amount?: number
          parent_id?: string
          payment_term_id?: string | null
          payment_term_outstanding?: number
          payment_type?: string | null
          reference_doctype?: string
          reference_id?: string
          total_amount?: number
        }
        Relationships: [
          {
            foreignKeyName: "payment_entry_reference_org_id_account_id_fkey"
            columns: ["org_id", "account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_entry_reference_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "payment_entry"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_entry_reference_org_id_payment_term_id_fkey"
            columns: ["org_id", "payment_term_id"]
            isOneToOne: false
            referencedRelation: "payment_term"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      payment_ledger_entry: {
        Row: {
          account_currency: string | null
          account_id: string
          account_type: string
          advance_voucher_id: string | null
          advance_voucher_type: string | null
          against_voucher_id: string | null
          against_voucher_no: string | null
          against_voucher_type: string | null
          amount: number
          amount_in_account_currency: number
          company_id: string
          cost_center_id: string | null
          created_at: string
          delinked: boolean
          due_date: string | null
          id: string
          org_id: string
          party_id: string
          party_type: string
          posting_date: string
          project_id: string | null
          remarks: string | null
          voucher_detail_id: string | null
          voucher_id: string
          voucher_no: string | null
          voucher_type: string
        }
        Insert: {
          account_currency?: string | null
          account_id: string
          account_type: string
          advance_voucher_id?: string | null
          advance_voucher_type?: string | null
          against_voucher_id?: string | null
          against_voucher_no?: string | null
          against_voucher_type?: string | null
          amount: number
          amount_in_account_currency: number
          company_id: string
          cost_center_id?: string | null
          created_at?: string
          delinked?: boolean
          due_date?: string | null
          id?: string
          org_id: string
          party_id: string
          party_type: string
          posting_date: string
          project_id?: string | null
          remarks?: string | null
          voucher_detail_id?: string | null
          voucher_id: string
          voucher_no?: string | null
          voucher_type: string
        }
        Update: {
          account_currency?: string | null
          account_id?: string
          account_type?: string
          advance_voucher_id?: string | null
          advance_voucher_type?: string | null
          against_voucher_id?: string | null
          against_voucher_no?: string | null
          against_voucher_type?: string | null
          amount?: number
          amount_in_account_currency?: number
          company_id?: string
          cost_center_id?: string | null
          created_at?: string
          delinked?: boolean
          due_date?: string | null
          id?: string
          org_id?: string
          party_id?: string
          party_type?: string
          posting_date?: string
          project_id?: string | null
          remarks?: string | null
          voucher_detail_id?: string | null
          voucher_id?: string
          voucher_no?: string | null
          voucher_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_ledger_entry_org_id_account_id_fkey"
            columns: ["org_id", "account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_ledger_entry_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_ledger_entry_org_id_cost_center_id_fkey"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_ledger_entry_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_term: {
        Row: {
          created_at: string
          created_by: string | null
          credit_days: number
          credit_months: number
          description: string | null
          discount: number | null
          discount_type: string
          discount_validity: number | null
          discount_validity_based_on: string
          due_date_based_on: string | null
          id: string
          invoice_portion: number | null
          mode_of_payment_id: string | null
          name: string
          org_id: string
          payment_term_name: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          credit_days?: number
          credit_months?: number
          description?: string | null
          discount?: number | null
          discount_type?: string
          discount_validity?: number | null
          discount_validity_based_on?: string
          due_date_based_on?: string | null
          id?: string
          invoice_portion?: number | null
          mode_of_payment_id?: string | null
          name: string
          org_id: string
          payment_term_name: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          credit_days?: number
          credit_months?: number
          description?: string | null
          discount?: number | null
          discount_type?: string
          discount_validity?: number | null
          discount_validity_based_on?: string
          due_date_based_on?: string | null
          id?: string
          invoice_portion?: number | null
          mode_of_payment_id?: string | null
          name?: string
          org_id?: string
          payment_term_name?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "payment_term_mode_fk"
            columns: ["org_id", "mode_of_payment_id"]
            isOneToOne: false
            referencedRelation: "mode_of_payment"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_term_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_terms_template: {
        Row: {
          allocate_payment_based_on_payment_terms: boolean
          created_at: string
          created_by: string | null
          id: string
          name: string
          org_id: string
          template_name: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          allocate_payment_based_on_payment_terms?: boolean
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          org_id: string
          template_name: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          allocate_payment_based_on_payment_terms?: boolean
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          org_id?: string
          template_name?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "payment_terms_template_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_terms_template_detail: {
        Row: {
          credit_days: number
          credit_months: number
          description: string | null
          discount: number | null
          discount_type: string
          discount_validity: number | null
          discount_validity_based_on: string | null
          due_date_based_on: string
          id: string
          idx: number
          invoice_portion: number
          mode_of_payment_id: string | null
          org_id: string
          parent_id: string
          payment_term_id: string | null
        }
        Insert: {
          credit_days?: number
          credit_months?: number
          description?: string | null
          discount?: number | null
          discount_type?: string
          discount_validity?: number | null
          discount_validity_based_on?: string | null
          due_date_based_on?: string
          id?: string
          idx: number
          invoice_portion: number
          mode_of_payment_id?: string | null
          org_id: string
          parent_id: string
          payment_term_id?: string | null
        }
        Update: {
          credit_days?: number
          credit_months?: number
          description?: string | null
          discount?: number | null
          discount_type?: string
          discount_validity?: number | null
          discount_validity_based_on?: string | null
          due_date_based_on?: string
          id?: string
          idx?: number
          invoice_portion?: number
          mode_of_payment_id?: string | null
          org_id?: string
          parent_id?: string
          payment_term_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "payment_terms_template_detail_mode_fk"
            columns: ["org_id", "mode_of_payment_id"]
            isOneToOne: false
            referencedRelation: "mode_of_payment"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_terms_template_detail_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "payment_terms_template"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "payment_terms_template_detail_term_fk"
            columns: ["org_id", "payment_term_id"]
            isOneToOne: false
            referencedRelation: "payment_term"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      price_list: {
        Row: {
          buying: boolean
          created_at: string
          created_by: string | null
          currency: string
          enabled: boolean
          id: string
          name: string
          org_id: string
          price_list_name: string
          price_not_uom_dependent: boolean
          selling: boolean
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          buying?: boolean
          created_at?: string
          created_by?: string | null
          currency: string
          enabled?: boolean
          id?: string
          name: string
          org_id: string
          price_list_name: string
          price_not_uom_dependent?: boolean
          selling?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          buying?: boolean
          created_at?: string
          created_by?: string | null
          currency?: string
          enabled?: boolean
          id?: string
          name?: string
          org_id?: string
          price_list_name?: string
          price_not_uom_dependent?: boolean
          selling?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "price_list_currency_fkey"
            columns: ["currency"]
            isOneToOne: false
            referencedRelation: "currency"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "price_list_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      print_format: {
        Row: {
          created_at: string
          created_by: string | null
          disabled: boolean
          doc_type: string
          id: string
          is_default: boolean
          is_standard: boolean
          name: string
          options: Json
          org_id: string
          template_key: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          doc_type: string
          id?: string
          is_default?: boolean
          is_standard?: boolean
          name: string
          options?: Json
          org_id: string
          template_key?: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          doc_type?: string
          id?: string
          is_default?: boolean
          is_standard?: boolean
          name?: string
          options?: Json
          org_id?: string
          template_key?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "print_format_doc_type_fkey"
            columns: ["doc_type"]
            isOneToOne: false
            referencedRelation: "doctype_meta"
            referencedColumns: ["doctype"]
          },
          {
            foreignKeyName: "print_format_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      print_heading: {
        Row: {
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          name: string
          org_id: string
          print_heading: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          name: string
          org_id: string
          print_heading: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          name?: string
          org_id?: string
          print_heading?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "print_heading_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      print_settings: {
        Row: {
          add_draft_heading: boolean
          allow_page_break_inside_tables: boolean
          allow_print_for_cancelled: boolean
          allow_print_for_draft: boolean
          attach_view_link: boolean
          compact_item_print: boolean
          created_at: string
          created_by: string | null
          font: string
          font_size: number
          id: string
          letter_head_id: string | null
          org_id: string
          pdf_page_height: number | null
          pdf_page_size: string
          pdf_page_width: number | null
          print_style: string
          print_taxes_with_zero_amount: boolean
          print_uom_after_quantity: boolean
          repeat_header_footer: boolean
          send_print_as_pdf: boolean
          updated_at: string
          updated_by: string | null
          with_letterhead: boolean
        }
        Insert: {
          add_draft_heading?: boolean
          allow_page_break_inside_tables?: boolean
          allow_print_for_cancelled?: boolean
          allow_print_for_draft?: boolean
          attach_view_link?: boolean
          compact_item_print?: boolean
          created_at?: string
          created_by?: string | null
          font?: string
          font_size?: number
          id?: string
          letter_head_id?: string | null
          org_id: string
          pdf_page_height?: number | null
          pdf_page_size?: string
          pdf_page_width?: number | null
          print_style?: string
          print_taxes_with_zero_amount?: boolean
          print_uom_after_quantity?: boolean
          repeat_header_footer?: boolean
          send_print_as_pdf?: boolean
          updated_at?: string
          updated_by?: string | null
          with_letterhead?: boolean
        }
        Update: {
          add_draft_heading?: boolean
          allow_page_break_inside_tables?: boolean
          allow_print_for_cancelled?: boolean
          allow_print_for_draft?: boolean
          attach_view_link?: boolean
          compact_item_print?: boolean
          created_at?: string
          created_by?: string | null
          font?: string
          font_size?: number
          id?: string
          letter_head_id?: string | null
          org_id?: string
          pdf_page_height?: number | null
          pdf_page_size?: string
          pdf_page_width?: number | null
          print_style?: string
          print_taxes_with_zero_amount?: boolean
          print_uom_after_quantity?: boolean
          repeat_header_footer?: boolean
          send_print_as_pdf?: boolean
          updated_at?: string
          updated_by?: string | null
          with_letterhead?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "print_settings_letter_head_fkey"
            columns: ["org_id", "letter_head_id"]
            isOneToOne: false
            referencedRelation: "letter_head"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "print_settings_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: true
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      product_bundle: {
        Row: {
          amended_from: string | null
          created_at: string
          created_by: string | null
          description: string | null
          disabled: boolean
          docstatus: number
          id: string
          is_active: boolean
          name: string
          new_item_id: string
          org_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          amended_from?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          disabled?: boolean
          docstatus?: number
          id?: string
          is_active?: boolean
          name: string
          new_item_id: string
          org_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          amended_from?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          disabled?: boolean
          docstatus?: number
          id?: string
          is_active?: boolean
          name?: string
          new_item_id?: string
          org_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "product_bundle_org_id_amended_from_fkey"
            columns: ["org_id", "amended_from"]
            isOneToOne: false
            referencedRelation: "product_bundle"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "product_bundle_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_bundle_org_id_new_item_id_fkey"
            columns: ["org_id", "new_item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      product_bundle_item: {
        Row: {
          description: string | null
          id: string
          idx: number
          item_id: string
          org_id: string
          parent_id: string
          qty: number
          uom_id: string | null
        }
        Insert: {
          description?: string | null
          id?: string
          idx: number
          item_id: string
          org_id: string
          parent_id: string
          qty: number
          uom_id?: string | null
        }
        Update: {
          description?: string | null
          id?: string
          idx?: number
          item_id?: string
          org_id?: string
          parent_id?: string
          qty?: number
          uom_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "product_bundle_item_org_id_item_id_fkey"
            columns: ["org_id", "item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "product_bundle_item_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "product_bundle"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "product_bundle_item_org_id_uom_id_fkey"
            columns: ["org_id", "uom_id"]
            isOneToOne: false
            referencedRelation: "uom"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      purchase_taxes_and_charges: {
        Row: {
          account_currency: string | null
          account_head_id: string
          add_deduct_tax: string
          allocate_full_amount_to_stock_items: boolean
          category: string
          charge_type: string
          cost_center_id: string | null
          created_at: string
          description: string
          id: string
          idx: number
          included_in_paid_amount: boolean
          included_in_print_rate: boolean
          org_id: string
          parent_id: string
          rate: number | null
          row_id: string | null
        }
        Insert: {
          account_currency?: string | null
          account_head_id: string
          add_deduct_tax?: string
          allocate_full_amount_to_stock_items?: boolean
          category?: string
          charge_type?: string
          cost_center_id?: string | null
          created_at?: string
          description: string
          id?: string
          idx: number
          included_in_paid_amount?: boolean
          included_in_print_rate?: boolean
          org_id: string
          parent_id: string
          rate?: number | null
          row_id?: string | null
        }
        Update: {
          account_currency?: string | null
          account_head_id?: string
          add_deduct_tax?: string
          allocate_full_amount_to_stock_items?: boolean
          category?: string
          charge_type?: string
          cost_center_id?: string | null
          created_at?: string
          description?: string
          id?: string
          idx?: number
          included_in_paid_amount?: boolean
          included_in_print_rate?: boolean
          org_id?: string
          parent_id?: string
          rate?: number | null
          row_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "purchase_taxes_and_charges_org_id_account_head_id_fkey"
            columns: ["org_id", "account_head_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "purchase_taxes_and_charges_org_id_cost_center_id_fkey"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "purchase_taxes_and_charges_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "purchase_taxes_and_charges_template"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      purchase_taxes_and_charges_template: {
        Row: {
          company_id: string
          created_at: string
          created_by: string | null
          disabled: boolean
          id: string
          is_default: boolean
          name: string
          org_id: string
          tax_category_id: string | null
          title: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          company_id: string
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          is_default?: boolean
          name: string
          org_id: string
          tax_category_id?: string | null
          title: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          company_id?: string
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          is_default?: boolean
          name?: string
          org_id?: string
          tax_category_id?: string | null
          title?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "purchase_taxes_and_charges_template_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "purchase_taxes_and_charges_template_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_taxes_and_charges_template_org_id_tax_category_id_fkey"
            columns: ["org_id", "tax_category_id"]
            isOneToOne: false
            referencedRelation: "tax_category"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      role_permission_template: {
        Row: {
          can_amend: boolean
          can_cancel: boolean
          can_create: boolean
          can_delete: boolean
          can_export: boolean
          can_read: boolean
          can_report: boolean
          can_submit: boolean
          can_write: boolean
          doctype: string
          if_owner: boolean
          role: string
        }
        Insert: {
          can_amend?: boolean
          can_cancel?: boolean
          can_create?: boolean
          can_delete?: boolean
          can_export?: boolean
          can_read?: boolean
          can_report?: boolean
          can_submit?: boolean
          can_write?: boolean
          doctype: string
          if_owner?: boolean
          role: string
        }
        Update: {
          can_amend?: boolean
          can_cancel?: boolean
          can_create?: boolean
          can_delete?: boolean
          can_export?: boolean
          can_read?: boolean
          can_report?: boolean
          can_submit?: boolean
          can_write?: boolean
          doctype?: string
          if_owner?: boolean
          role?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_permission_template_role_fkey"
            columns: ["role"]
            isOneToOne: false
            referencedRelation: "role_template"
            referencedColumns: ["name"]
          },
        ]
      }
      role_permissions: {
        Row: {
          can_amend: boolean
          can_cancel: boolean
          can_create: boolean
          can_delete: boolean
          can_export: boolean
          can_read: boolean
          can_report: boolean
          can_submit: boolean
          can_write: boolean
          created_at: string
          created_by: string | null
          doctype: string
          if_owner: boolean
          org_id: string
          role: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          can_amend?: boolean
          can_cancel?: boolean
          can_create?: boolean
          can_delete?: boolean
          can_export?: boolean
          can_read?: boolean
          can_report?: boolean
          can_submit?: boolean
          can_write?: boolean
          created_at?: string
          created_by?: string | null
          doctype: string
          if_owner?: boolean
          org_id: string
          role: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          can_amend?: boolean
          can_cancel?: boolean
          can_create?: boolean
          can_delete?: boolean
          can_export?: boolean
          can_read?: boolean
          can_report?: boolean
          can_submit?: boolean
          can_write?: boolean
          created_at?: string
          created_by?: string | null
          doctype?: string
          if_owner?: boolean
          org_id?: string
          role?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_org_id_role_fkey"
            columns: ["org_id", "role"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["org_id", "name"]
          },
        ]
      }
      role_profile: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          name: string
          org_id: string
          roles: string[]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          org_id: string
          roles?: string[]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          org_id?: string
          roles?: string[]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "role_profile_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      role_profile_template: {
        Row: {
          name: string
          roles: string[]
        }
        Insert: {
          name: string
          roles?: string[]
        }
        Update: {
          name?: string
          roles?: string[]
        }
        Relationships: []
      }
      role_template: {
        Row: {
          name: string
        }
        Insert: {
          name: string
        }
        Update: {
          name?: string
        }
        Relationships: []
      }
      roles: {
        Row: {
          created_at: string
          created_by: string | null
          disabled: boolean
          id: string
          is_standard: boolean
          name: string
          org_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          is_standard?: boolean
          name: string
          org_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          is_standard?: boolean
          name?: string
          org_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "roles_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      sales_person: {
        Row: {
          commission_rate: number
          created_at: string
          created_by: string | null
          enabled: boolean
          id: string
          is_group: boolean
          org_id: string
          parent_id: string | null
          path: unknown
          sales_person_name: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          commission_rate?: number
          created_at?: string
          created_by?: string | null
          enabled?: boolean
          id?: string
          is_group?: boolean
          org_id: string
          parent_id?: string | null
          path: unknown
          sales_person_name: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          commission_rate?: number
          created_at?: string
          created_by?: string | null
          enabled?: boolean
          id?: string
          is_group?: boolean
          org_id?: string
          parent_id?: string | null
          path?: unknown
          sales_person_name?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "sales_person_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sales_person_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "sales_person"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      sales_taxes_and_charges: {
        Row: {
          account_currency: string | null
          account_head_id: string
          charge_type: string
          cost_center_id: string | null
          created_at: string
          description: string
          id: string
          idx: number
          included_in_paid_amount: boolean
          included_in_print_rate: boolean
          org_id: string
          parent_id: string
          rate: number | null
          row_id: string | null
        }
        Insert: {
          account_currency?: string | null
          account_head_id: string
          charge_type: string
          cost_center_id?: string | null
          created_at?: string
          description: string
          id?: string
          idx: number
          included_in_paid_amount?: boolean
          included_in_print_rate?: boolean
          org_id: string
          parent_id: string
          rate?: number | null
          row_id?: string | null
        }
        Update: {
          account_currency?: string | null
          account_head_id?: string
          charge_type?: string
          cost_center_id?: string | null
          created_at?: string
          description?: string
          id?: string
          idx?: number
          included_in_paid_amount?: boolean
          included_in_print_rate?: boolean
          org_id?: string
          parent_id?: string
          rate?: number | null
          row_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "sales_taxes_and_charges_org_id_account_head_id_fkey"
            columns: ["org_id", "account_head_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "sales_taxes_and_charges_org_id_cost_center_id_fkey"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "sales_taxes_and_charges_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "sales_taxes_and_charges_template"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      sales_taxes_and_charges_template: {
        Row: {
          company_id: string
          created_at: string
          created_by: string | null
          disabled: boolean
          id: string
          is_default: boolean
          name: string
          org_id: string
          tax_category_id: string | null
          title: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          company_id: string
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          is_default?: boolean
          name: string
          org_id: string
          tax_category_id?: string | null
          title: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          company_id?: string
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          is_default?: boolean
          name?: string
          org_id?: string
          tax_category_id?: string | null
          title?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "sales_taxes_and_charges_template_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "sales_taxes_and_charges_template_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sales_taxes_and_charges_template_org_id_tax_category_id_fkey"
            columns: ["org_id", "tax_category_id"]
            isOneToOne: false
            referencedRelation: "tax_category"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      serial_and_batch_bundle: {
        Row: {
          amended_from: string | null
          company_id: string
          created_at: string
          created_by: string | null
          docstatus: number
          id: string
          item_id: string
          name: string
          naming_series: string
          org_id: string
          posting_datetime: string
          total_qty: number
          type_of_transaction: string
          updated_at: string
          updated_by: string | null
          voucher_id: string | null
          voucher_type: string
          warehouse_id: string
        }
        Insert: {
          amended_from?: string | null
          company_id: string
          created_at?: string
          created_by?: string | null
          docstatus?: number
          id?: string
          item_id: string
          name: string
          naming_series?: string
          org_id: string
          posting_datetime?: string
          total_qty?: number
          type_of_transaction: string
          updated_at?: string
          updated_by?: string | null
          voucher_id?: string | null
          voucher_type: string
          warehouse_id: string
        }
        Update: {
          amended_from?: string | null
          company_id?: string
          created_at?: string
          created_by?: string | null
          docstatus?: number
          id?: string
          item_id?: string
          name?: string
          naming_series?: string
          org_id?: string
          posting_datetime?: string
          total_qty?: number
          type_of_transaction?: string
          updated_at?: string
          updated_by?: string | null
          voucher_id?: string | null
          voucher_type?: string
          warehouse_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "serial_and_batch_bundle_org_id_amended_from_fkey"
            columns: ["org_id", "amended_from"]
            isOneToOne: false
            referencedRelation: "serial_and_batch_bundle"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "serial_and_batch_bundle_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "serial_and_batch_bundle_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "serial_and_batch_bundle_org_id_item_id_fkey"
            columns: ["org_id", "item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "serial_and_batch_bundle_org_id_warehouse_id_fkey"
            columns: ["org_id", "warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      serial_and_batch_entry: {
        Row: {
          batch_id: string | null
          id: string
          idx: number
          incoming_rate: number
          org_id: string
          parent_id: string
          qty: number
          serial_no_id: string | null
        }
        Insert: {
          batch_id?: string | null
          id?: string
          idx: number
          incoming_rate?: number
          org_id: string
          parent_id: string
          qty: number
          serial_no_id?: string | null
        }
        Update: {
          batch_id?: string | null
          id?: string
          idx?: number
          incoming_rate?: number
          org_id?: string
          parent_id?: string
          qty?: number
          serial_no_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "serial_and_batch_entry_org_id_batch_id_fkey"
            columns: ["org_id", "batch_id"]
            isOneToOne: false
            referencedRelation: "batch"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "serial_and_batch_entry_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "serial_and_batch_bundle"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "serial_and_batch_entry_org_id_serial_no_id_fkey"
            columns: ["org_id", "serial_no_id"]
            isOneToOne: false
            referencedRelation: "serial_no"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      serial_no: {
        Row: {
          batch_id: string | null
          company_id: string
          created_at: string
          created_by: string | null
          customer_id: string | null
          id: string
          item_id: string
          name: string
          org_id: string
          purchase_rate: number
          serial_no: string
          updated_at: string
          updated_by: string | null
          warehouse_id: string | null
          warranty_expiry_date: string | null
        }
        Insert: {
          batch_id?: string | null
          company_id: string
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          id?: string
          item_id: string
          name: string
          org_id: string
          purchase_rate?: number
          serial_no: string
          updated_at?: string
          updated_by?: string | null
          warehouse_id?: string | null
          warranty_expiry_date?: string | null
        }
        Update: {
          batch_id?: string | null
          company_id?: string
          created_at?: string
          created_by?: string | null
          customer_id?: string | null
          id?: string
          item_id?: string
          name?: string
          org_id?: string
          purchase_rate?: number
          serial_no?: string
          updated_at?: string
          updated_by?: string | null
          warehouse_id?: string | null
          warranty_expiry_date?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "serial_no_org_id_batch_id_fkey"
            columns: ["org_id", "batch_id"]
            isOneToOne: false
            referencedRelation: "batch"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "serial_no_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "serial_no_org_id_customer_id_fkey"
            columns: ["org_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "customer"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "serial_no_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "serial_no_org_id_item_id_fkey"
            columns: ["org_id", "item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "serial_no_org_id_warehouse_id_fkey"
            columns: ["org_id", "warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      stock_entry: {
        Row: {
          add_to_transit: boolean
          amended_from: string | null
          bom_no: string | null
          company_id: string
          cost_center_id: string | null
          created_at: string
          created_by: string | null
          docstatus: number
          fg_completed_qty: number
          from_warehouse_id: string | null
          id: string
          is_opening: string
          name: string
          naming_series: string
          org_id: string
          outgoing_stock_entry_id: string | null
          posting_date: string
          posting_time: string
          project: string | null
          purpose: string
          remarks: string | null
          set_posting_time: boolean
          stock_entry_type_id: string
          title: string | null
          to_warehouse_id: string | null
          total_incoming_value: number
          total_outgoing_value: number
          updated_at: string
          updated_by: string | null
          use_multi_level_bom: boolean
          value_difference: number
          work_order_id: string | null
        }
        Insert: {
          add_to_transit?: boolean
          amended_from?: string | null
          bom_no?: string | null
          company_id: string
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          docstatus?: number
          fg_completed_qty?: number
          from_warehouse_id?: string | null
          id?: string
          is_opening?: string
          name: string
          naming_series?: string
          org_id: string
          outgoing_stock_entry_id?: string | null
          posting_date?: string
          posting_time?: string
          project?: string | null
          purpose: string
          remarks?: string | null
          set_posting_time?: boolean
          stock_entry_type_id: string
          title?: string | null
          to_warehouse_id?: string | null
          total_incoming_value?: number
          total_outgoing_value?: number
          updated_at?: string
          updated_by?: string | null
          use_multi_level_bom?: boolean
          value_difference?: number
          work_order_id?: string | null
        }
        Update: {
          add_to_transit?: boolean
          amended_from?: string | null
          bom_no?: string | null
          company_id?: string
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          docstatus?: number
          fg_completed_qty?: number
          from_warehouse_id?: string | null
          id?: string
          is_opening?: string
          name?: string
          naming_series?: string
          org_id?: string
          outgoing_stock_entry_id?: string | null
          posting_date?: string
          posting_time?: string
          project?: string | null
          purpose?: string
          remarks?: string | null
          set_posting_time?: boolean
          stock_entry_type_id?: string
          title?: string | null
          to_warehouse_id?: string | null
          total_incoming_value?: number
          total_outgoing_value?: number
          updated_at?: string
          updated_by?: string | null
          use_multi_level_bom?: boolean
          value_difference?: number
          work_order_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_entry_org_id_amended_from_fkey"
            columns: ["org_id", "amended_from"]
            isOneToOne: false
            referencedRelation: "stock_entry"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_org_id_cost_center_id_fkey"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_entry_org_id_from_warehouse_id_fkey"
            columns: ["org_id", "from_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_org_id_outgoing_stock_entry_id_fkey"
            columns: ["org_id", "outgoing_stock_entry_id"]
            isOneToOne: false
            referencedRelation: "stock_entry"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_org_id_stock_entry_type_id_fkey"
            columns: ["org_id", "stock_entry_type_id"]
            isOneToOne: false
            referencedRelation: "stock_entry_type"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_org_id_to_warehouse_id_fkey"
            columns: ["org_id", "to_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      stock_entry_additional_cost: {
        Row: {
          amount: number
          description: string | null
          expense_account_id: string
          id: string
          idx: number
          org_id: string
          parent_id: string
        }
        Insert: {
          amount?: number
          description?: string | null
          expense_account_id: string
          id?: string
          idx: number
          org_id: string
          parent_id: string
        }
        Update: {
          amount?: number
          description?: string | null
          expense_account_id?: string
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_entry_additional_cost_org_id_expense_account_id_fkey"
            columns: ["org_id", "expense_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_additional_cost_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "stock_entry"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      stock_entry_detail: {
        Row: {
          additional_cost: number
          allow_zero_valuation_rate: boolean
          amount: number
          basic_amount: number
          basic_rate: number
          batch_no: string | null
          conversion_factor: number
          cost_center_id: string | null
          expense_account_id: string | null
          id: string
          idx: number
          is_finished_item: boolean
          item_id: string
          material_request_id: string | null
          material_request_item: string | null
          org_id: string
          parent_id: string
          per_transferred: number
          qty: number
          s_warehouse_id: string | null
          serial_and_batch_bundle: string | null
          serial_no: string | null
          t_warehouse_id: string | null
          transfer_qty: number
          uom_id: string
          use_serial_batch_fields: boolean
          valuation_rate: number
        }
        Insert: {
          additional_cost?: number
          allow_zero_valuation_rate?: boolean
          amount?: number
          basic_amount?: number
          basic_rate?: number
          batch_no?: string | null
          conversion_factor?: number
          cost_center_id?: string | null
          expense_account_id?: string | null
          id?: string
          idx: number
          is_finished_item?: boolean
          item_id: string
          material_request_id?: string | null
          material_request_item?: string | null
          org_id: string
          parent_id: string
          per_transferred?: number
          qty: number
          s_warehouse_id?: string | null
          serial_and_batch_bundle?: string | null
          serial_no?: string | null
          t_warehouse_id?: string | null
          transfer_qty?: number
          uom_id: string
          use_serial_batch_fields?: boolean
          valuation_rate?: number
        }
        Update: {
          additional_cost?: number
          allow_zero_valuation_rate?: boolean
          amount?: number
          basic_amount?: number
          basic_rate?: number
          batch_no?: string | null
          conversion_factor?: number
          cost_center_id?: string | null
          expense_account_id?: string | null
          id?: string
          idx?: number
          is_finished_item?: boolean
          item_id?: string
          material_request_id?: string | null
          material_request_item?: string | null
          org_id?: string
          parent_id?: string
          per_transferred?: number
          qty?: number
          s_warehouse_id?: string | null
          serial_and_batch_bundle?: string | null
          serial_no?: string | null
          t_warehouse_id?: string | null
          transfer_qty?: number
          uom_id?: string
          use_serial_batch_fields?: boolean
          valuation_rate?: number
        }
        Relationships: [
          {
            foreignKeyName: "stock_entry_detail_material_request_fkey"
            columns: ["org_id", "material_request_id"]
            isOneToOne: false
            referencedRelation: "material_request"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_detail_material_request_item_fkey"
            columns: ["org_id", "material_request_item"]
            isOneToOne: false
            referencedRelation: "material_request_item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_detail_org_id_cost_center_id_fkey"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_detail_org_id_expense_account_id_fkey"
            columns: ["org_id", "expense_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_detail_org_id_item_id_fkey"
            columns: ["org_id", "item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_detail_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "stock_entry"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_detail_org_id_s_warehouse_id_fkey"
            columns: ["org_id", "s_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_detail_org_id_t_warehouse_id_fkey"
            columns: ["org_id", "t_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_entry_detail_org_id_uom_id_fkey"
            columns: ["org_id", "uom_id"]
            isOneToOne: false
            referencedRelation: "uom"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      stock_entry_type: {
        Row: {
          add_to_transit: boolean
          created_at: string
          created_by: string | null
          id: string
          is_standard: boolean
          name: string
          org_id: string
          purpose: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          add_to_transit?: boolean
          created_at?: string
          created_by?: string | null
          id?: string
          is_standard?: boolean
          name: string
          org_id: string
          purpose: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          add_to_transit?: boolean
          created_at?: string
          created_by?: string | null
          id?: string
          is_standard?: boolean
          name?: string
          org_id?: string
          purpose?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_entry_type_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_ledger_entry: {
        Row: {
          actual_qty: number
          batch_id: string | null
          company_id: string
          cost_center_id: string | null
          created_at: string
          creation_order: number
          expense_account_id: string | null
          fiscal_year_id: string | null
          has_batch_no: boolean
          has_serial_no: boolean
          id: string
          incoming_rate: number
          is_adjustment_entry: boolean
          is_cancelled: boolean
          is_opening: boolean
          item_id: string
          org_id: string
          outgoing_rate: number
          posting_date: string
          posting_datetime: string
          posting_time: string
          project_id: string | null
          qty_after_transaction: number
          serial_and_batch_bundle_id: string | null
          stock_queue: Json
          stock_uom_id: string
          stock_value: number
          stock_value_difference: number
          valuation_rate: number
          voucher_detail_id: string | null
          voucher_id: string
          voucher_no: string
          voucher_type: string
          warehouse_id: string
        }
        Insert: {
          actual_qty: number
          batch_id?: string | null
          company_id: string
          cost_center_id?: string | null
          created_at?: string
          creation_order?: number
          expense_account_id?: string | null
          fiscal_year_id?: string | null
          has_batch_no?: boolean
          has_serial_no?: boolean
          id?: string
          incoming_rate?: number
          is_adjustment_entry?: boolean
          is_cancelled?: boolean
          is_opening?: boolean
          item_id: string
          org_id: string
          outgoing_rate?: number
          posting_date: string
          posting_datetime: string
          posting_time: string
          project_id?: string | null
          qty_after_transaction?: number
          serial_and_batch_bundle_id?: string | null
          stock_queue?: Json
          stock_uom_id: string
          stock_value?: number
          stock_value_difference?: number
          valuation_rate?: number
          voucher_detail_id?: string | null
          voucher_id: string
          voucher_no: string
          voucher_type: string
          warehouse_id: string
        }
        Update: {
          actual_qty?: number
          batch_id?: string | null
          company_id?: string
          cost_center_id?: string | null
          created_at?: string
          creation_order?: number
          expense_account_id?: string | null
          fiscal_year_id?: string | null
          has_batch_no?: boolean
          has_serial_no?: boolean
          id?: string
          incoming_rate?: number
          is_adjustment_entry?: boolean
          is_cancelled?: boolean
          is_opening?: boolean
          item_id?: string
          org_id?: string
          outgoing_rate?: number
          posting_date?: string
          posting_datetime?: string
          posting_time?: string
          project_id?: string | null
          qty_after_transaction?: number
          serial_and_batch_bundle_id?: string | null
          stock_queue?: Json
          stock_uom_id?: string
          stock_value?: number
          stock_value_difference?: number
          valuation_rate?: number
          voucher_detail_id?: string | null
          voucher_id?: string
          voucher_no?: string
          voucher_type?: string
          warehouse_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_ledger_entry_batch_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "batch"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_ledger_entry_bundle_fkey"
            columns: ["serial_and_batch_bundle_id"]
            isOneToOne: false
            referencedRelation: "serial_and_batch_bundle"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_ledger_entry_cost_center_fk"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_ledger_entry_expense_account_fk"
            columns: ["org_id", "expense_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_ledger_entry_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_ledger_entry_org_id_fiscal_year_id_fkey"
            columns: ["org_id", "fiscal_year_id"]
            isOneToOne: false
            referencedRelation: "fiscal_year"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_ledger_entry_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_ledger_entry_org_id_item_id_fkey"
            columns: ["org_id", "item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_ledger_entry_org_id_stock_uom_id_fkey"
            columns: ["org_id", "stock_uom_id"]
            isOneToOne: false
            referencedRelation: "uom"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_ledger_entry_org_id_warehouse_id_fkey"
            columns: ["org_id", "warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      stock_reconciliation: {
        Row: {
          amended_from: string | null
          company_id: string
          cost_center_id: string | null
          created_at: string
          created_by: string | null
          difference_amount: number
          docstatus: number
          expense_account_id: string | null
          id: string
          name: string
          naming_series: string
          org_id: string
          posting_date: string
          posting_time: string
          purpose: string
          set_warehouse_id: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          amended_from?: string | null
          company_id: string
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          difference_amount?: number
          docstatus?: number
          expense_account_id?: string | null
          id?: string
          name: string
          naming_series?: string
          org_id: string
          posting_date?: string
          posting_time?: string
          purpose: string
          set_warehouse_id?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          amended_from?: string | null
          company_id?: string
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          difference_amount?: number
          docstatus?: number
          expense_account_id?: string | null
          id?: string
          name?: string
          naming_series?: string
          org_id?: string
          posting_date?: string
          posting_time?: string
          purpose?: string
          set_warehouse_id?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_reconciliation_org_id_amended_from_fkey"
            columns: ["org_id", "amended_from"]
            isOneToOne: false
            referencedRelation: "stock_reconciliation"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_reconciliation_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_reconciliation_org_id_cost_center_id_fkey"
            columns: ["org_id", "cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_center"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_reconciliation_org_id_expense_account_id_fkey"
            columns: ["org_id", "expense_account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_reconciliation_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_reconciliation_org_id_set_warehouse_id_fkey"
            columns: ["org_id", "set_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      stock_reconciliation_item: {
        Row: {
          allow_zero_valuation_rate: boolean
          amount_difference: number
          batch_no: string | null
          current_amount: number
          current_qty: number
          current_valuation_rate: number
          id: string
          idx: number
          item_id: string
          org_id: string
          parent_id: string
          qty: number
          quantity_difference: number
          serial_and_batch_bundle: string | null
          serial_no: string | null
          valuation_rate: number
          warehouse_id: string | null
        }
        Insert: {
          allow_zero_valuation_rate?: boolean
          amount_difference?: number
          batch_no?: string | null
          current_amount?: number
          current_qty?: number
          current_valuation_rate?: number
          id?: string
          idx: number
          item_id: string
          org_id: string
          parent_id: string
          qty?: number
          quantity_difference?: number
          serial_and_batch_bundle?: string | null
          serial_no?: string | null
          valuation_rate?: number
          warehouse_id?: string | null
        }
        Update: {
          allow_zero_valuation_rate?: boolean
          amount_difference?: number
          batch_no?: string | null
          current_amount?: number
          current_qty?: number
          current_valuation_rate?: number
          id?: string
          idx?: number
          item_id?: string
          org_id?: string
          parent_id?: string
          qty?: number
          quantity_difference?: number
          serial_and_batch_bundle?: string | null
          serial_no?: string | null
          valuation_rate?: number
          warehouse_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_reconciliation_item_org_id_item_id_fkey"
            columns: ["org_id", "item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_reconciliation_item_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "stock_reconciliation"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "stock_reconciliation_item_org_id_warehouse_id_fkey"
            columns: ["org_id", "warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      stock_settings: {
        Row: {
          action_if_quality_inspection_is_not_submitted: string
          action_if_quality_inspection_is_rejected: string
          allow_existing_serial_no: boolean
          allow_negative_stock: boolean
          allow_to_edit_stock_uom_qty_for_purchase: boolean
          allow_to_edit_stock_uom_qty_for_sales: boolean
          allow_to_edit_stock_uom_qty_for_stock_entry: boolean
          auto_create_serial_and_batch_bundle_for_outward: boolean
          auto_indent: boolean
          auto_insert_price_list_rate_if_missing: boolean
          clean_description_html: boolean
          created_at: string
          created_by: string | null
          do_not_use_batchwise_valuation: boolean
          enable_stock_reservation: boolean
          id: string
          item_naming_by: string
          mr_qty_allowance: number | null
          org_id: string
          over_delivery_receipt_allowance: number | null
          over_picking_allowance: number | null
          pick_serial_and_batch_based_on: string
          role_allowed_to_over_deliver_receive: string | null
          set_qty_in_transactions_based_on_serial_no_input: boolean
          show_barcode_field: boolean
          stock_auth_role: string | null
          stock_frozen_upto: string | null
          stock_frozen_upto_days: number | null
          stock_uom_id: string | null
          update_price_list_based_on: string
          updated_at: string
          updated_by: string | null
          use_serial_batch_fields: boolean
          validate_material_transfer_warehouses: boolean
          valuation_method: string
        }
        Insert: {
          action_if_quality_inspection_is_not_submitted?: string
          action_if_quality_inspection_is_rejected?: string
          allow_existing_serial_no?: boolean
          allow_negative_stock?: boolean
          allow_to_edit_stock_uom_qty_for_purchase?: boolean
          allow_to_edit_stock_uom_qty_for_sales?: boolean
          allow_to_edit_stock_uom_qty_for_stock_entry?: boolean
          auto_create_serial_and_batch_bundle_for_outward?: boolean
          auto_indent?: boolean
          auto_insert_price_list_rate_if_missing?: boolean
          clean_description_html?: boolean
          created_at?: string
          created_by?: string | null
          do_not_use_batchwise_valuation?: boolean
          enable_stock_reservation?: boolean
          id?: string
          item_naming_by?: string
          mr_qty_allowance?: number | null
          org_id: string
          over_delivery_receipt_allowance?: number | null
          over_picking_allowance?: number | null
          pick_serial_and_batch_based_on?: string
          role_allowed_to_over_deliver_receive?: string | null
          set_qty_in_transactions_based_on_serial_no_input?: boolean
          show_barcode_field?: boolean
          stock_auth_role?: string | null
          stock_frozen_upto?: string | null
          stock_frozen_upto_days?: number | null
          stock_uom_id?: string | null
          update_price_list_based_on?: string
          updated_at?: string
          updated_by?: string | null
          use_serial_batch_fields?: boolean
          validate_material_transfer_warehouses?: boolean
          valuation_method?: string
        }
        Update: {
          action_if_quality_inspection_is_not_submitted?: string
          action_if_quality_inspection_is_rejected?: string
          allow_existing_serial_no?: boolean
          allow_negative_stock?: boolean
          allow_to_edit_stock_uom_qty_for_purchase?: boolean
          allow_to_edit_stock_uom_qty_for_sales?: boolean
          allow_to_edit_stock_uom_qty_for_stock_entry?: boolean
          auto_create_serial_and_batch_bundle_for_outward?: boolean
          auto_indent?: boolean
          auto_insert_price_list_rate_if_missing?: boolean
          clean_description_html?: boolean
          created_at?: string
          created_by?: string | null
          do_not_use_batchwise_valuation?: boolean
          enable_stock_reservation?: boolean
          id?: string
          item_naming_by?: string
          mr_qty_allowance?: number | null
          org_id?: string
          over_delivery_receipt_allowance?: number | null
          over_picking_allowance?: number | null
          pick_serial_and_batch_based_on?: string
          role_allowed_to_over_deliver_receive?: string | null
          set_qty_in_transactions_based_on_serial_no_input?: boolean
          show_barcode_field?: boolean
          stock_auth_role?: string | null
          stock_frozen_upto?: string | null
          stock_frozen_upto_days?: number | null
          stock_uom_id?: string | null
          update_price_list_based_on?: string
          updated_at?: string
          updated_by?: string | null
          use_serial_batch_fields?: boolean
          validate_material_transfer_warehouses?: boolean
          valuation_method?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_settings_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: true
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_settings_org_id_role_allowed_to_over_deliver_receive_fkey"
            columns: ["org_id", "role_allowed_to_over_deliver_receive"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["org_id", "name"]
          },
          {
            foreignKeyName: "stock_settings_org_id_stock_auth_role_fkey"
            columns: ["org_id", "stock_auth_role"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["org_id", "name"]
          },
          {
            foreignKeyName: "stock_settings_org_id_stock_uom_id_fkey"
            columns: ["org_id", "stock_uom_id"]
            isOneToOne: false
            referencedRelation: "uom"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      supplier: {
        Row: {
          alias: string | null
          allow_purchase_invoice_creation_without_purchase_order: boolean
          allow_purchase_invoice_creation_without_purchase_receipt: boolean
          country: string | null
          created_at: string
          created_by: string | null
          default_currency: string | null
          default_price_list_id: string | null
          disabled: boolean
          hold_type: string | null
          id: string
          is_frozen: boolean
          is_transporter: boolean
          language: string | null
          name: string
          on_hold: boolean
          org_id: string
          payment_terms_id: string | null
          prevent_pos: boolean
          prevent_rfqs: boolean
          release_date: string | null
          supplier_details: string | null
          supplier_group_id: string | null
          supplier_name: string
          supplier_primary_address: string | null
          supplier_primary_contact: string | null
          supplier_type: string
          tax_category_id: string | null
          tax_id: string | null
          updated_at: string
          updated_by: string | null
          warn_pos: boolean
          warn_rfqs: boolean
          website: string | null
        }
        Insert: {
          alias?: string | null
          allow_purchase_invoice_creation_without_purchase_order?: boolean
          allow_purchase_invoice_creation_without_purchase_receipt?: boolean
          country?: string | null
          created_at?: string
          created_by?: string | null
          default_currency?: string | null
          default_price_list_id?: string | null
          disabled?: boolean
          hold_type?: string | null
          id?: string
          is_frozen?: boolean
          is_transporter?: boolean
          language?: string | null
          name: string
          on_hold?: boolean
          org_id: string
          payment_terms_id?: string | null
          prevent_pos?: boolean
          prevent_rfqs?: boolean
          release_date?: string | null
          supplier_details?: string | null
          supplier_group_id?: string | null
          supplier_name: string
          supplier_primary_address?: string | null
          supplier_primary_contact?: string | null
          supplier_type?: string
          tax_category_id?: string | null
          tax_id?: string | null
          updated_at?: string
          updated_by?: string | null
          warn_pos?: boolean
          warn_rfqs?: boolean
          website?: string | null
        }
        Update: {
          alias?: string | null
          allow_purchase_invoice_creation_without_purchase_order?: boolean
          allow_purchase_invoice_creation_without_purchase_receipt?: boolean
          country?: string | null
          created_at?: string
          created_by?: string | null
          default_currency?: string | null
          default_price_list_id?: string | null
          disabled?: boolean
          hold_type?: string | null
          id?: string
          is_frozen?: boolean
          is_transporter?: boolean
          language?: string | null
          name?: string
          on_hold?: boolean
          org_id?: string
          payment_terms_id?: string | null
          prevent_pos?: boolean
          prevent_rfqs?: boolean
          release_date?: string | null
          supplier_details?: string | null
          supplier_group_id?: string | null
          supplier_name?: string
          supplier_primary_address?: string | null
          supplier_primary_contact?: string | null
          supplier_type?: string
          tax_category_id?: string | null
          tax_id?: string | null
          updated_at?: string
          updated_by?: string | null
          warn_pos?: boolean
          warn_rfqs?: boolean
          website?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "coa_template_country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "supplier_country_fkey"
            columns: ["country"]
            isOneToOne: false
            referencedRelation: "country"
            referencedColumns: ["country_name"]
          },
          {
            foreignKeyName: "supplier_org_id_default_price_list_id_fkey"
            columns: ["org_id", "default_price_list_id"]
            isOneToOne: false
            referencedRelation: "price_list"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "supplier_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_org_id_payment_terms_id_fkey"
            columns: ["org_id", "payment_terms_id"]
            isOneToOne: false
            referencedRelation: "payment_terms_template"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "supplier_org_id_supplier_group_id_fkey"
            columns: ["org_id", "supplier_group_id"]
            isOneToOne: false
            referencedRelation: "supplier_group"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "supplier_org_id_supplier_primary_address_fkey"
            columns: ["org_id", "supplier_primary_address"]
            isOneToOne: false
            referencedRelation: "address"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "supplier_org_id_supplier_primary_contact_fkey"
            columns: ["org_id", "supplier_primary_contact"]
            isOneToOne: false
            referencedRelation: "contact"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "supplier_org_id_tax_category_id_fkey"
            columns: ["org_id", "tax_category_id"]
            isOneToOne: false
            referencedRelation: "tax_category"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      supplier_group: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          is_group: boolean
          org_id: string
          parent_id: string | null
          path: unknown
          payment_terms_id: string | null
          supplier_group_name: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_group?: boolean
          org_id: string
          parent_id?: string | null
          path: unknown
          payment_terms_id?: string | null
          supplier_group_name: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_group?: boolean
          org_id?: string
          parent_id?: string | null
          path?: unknown
          payment_terms_id?: string | null
          supplier_group_name?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_group_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_group_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "supplier_group"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "supplier_group_payment_terms_fk"
            columns: ["org_id", "payment_terms_id"]
            isOneToOne: false
            referencedRelation: "payment_terms_template"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      supplier_group_party_account: {
        Row: {
          account_id: string | null
          company_id: string
          id: string
          idx: number
          org_id: string
          parent_id: string
        }
        Insert: {
          account_id?: string | null
          company_id: string
          id?: string
          idx: number
          org_id: string
          parent_id: string
        }
        Update: {
          account_id?: string | null
          company_id?: string
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "supplier_group_party_account_org_id_account_id_fkey"
            columns: ["org_id", "account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "supplier_group_party_account_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "supplier_group_party_account_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_group_party_account_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "supplier_group"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      supplier_party_account: {
        Row: {
          account_id: string | null
          company_id: string
          id: string
          idx: number
          org_id: string
          parent_id: string
        }
        Insert: {
          account_id?: string | null
          company_id: string
          id?: string
          idx: number
          org_id: string
          parent_id: string
        }
        Update: {
          account_id?: string | null
          company_id?: string
          id?: string
          idx?: number
          org_id?: string
          parent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "supplier_party_account_org_id_account_id_fkey"
            columns: ["org_id", "account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "supplier_party_account_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "supplier_party_account_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_party_account_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "supplier"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      system_settings: {
        Row: {
          app_name: string
          created_at: string
          created_by: string | null
          currency_precision: string | null
          date_format: string
          email_footer_address: string | null
          first_day_of_the_week: string
          float_precision: string
          id: string
          language: string
          number_format: string
          org_id: string
          time_format: string
          time_zone: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          app_name?: string
          created_at?: string
          created_by?: string | null
          currency_precision?: string | null
          date_format?: string
          email_footer_address?: string | null
          first_day_of_the_week?: string
          float_precision?: string
          id?: string
          language?: string
          number_format?: string
          org_id: string
          time_format?: string
          time_zone?: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          app_name?: string
          created_at?: string
          created_by?: string | null
          currency_precision?: string | null
          date_format?: string
          email_footer_address?: string | null
          first_day_of_the_week?: string
          float_precision?: string
          id?: string
          language?: string
          number_format?: string
          org_id?: string
          time_format?: string
          time_zone?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "system_settings_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: true
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      tax_category: {
        Row: {
          created_at: string
          created_by: string | null
          disabled: boolean
          id: string
          name: string
          org_id: string
          title: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          name: string
          org_id: string
          title: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          name?: string
          org_id?: string
          title?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "tax_category_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      tax_rule: {
        Row: {
          billing_city: string | null
          billing_country: string | null
          billing_county: string | null
          billing_state: string | null
          billing_zipcode: string | null
          company_id: string
          created_at: string
          created_by: string | null
          customer_group_id: string | null
          customer_id: string | null
          from_date: string | null
          id: string
          item_group_id: string | null
          item_id: string | null
          name: string
          org_id: string
          priority: number
          purchase_tax_template_id: string | null
          sales_tax_template_id: string | null
          shipping_city: string | null
          shipping_country: string | null
          shipping_county: string | null
          shipping_state: string | null
          shipping_zipcode: string | null
          supplier_group_id: string | null
          supplier_id: string | null
          tax_category_id: string | null
          tax_type: string
          to_date: string | null
          updated_at: string
          updated_by: string | null
          use_for_shopping_cart: boolean
        }
        Insert: {
          billing_city?: string | null
          billing_country?: string | null
          billing_county?: string | null
          billing_state?: string | null
          billing_zipcode?: string | null
          company_id: string
          created_at?: string
          created_by?: string | null
          customer_group_id?: string | null
          customer_id?: string | null
          from_date?: string | null
          id?: string
          item_group_id?: string | null
          item_id?: string | null
          name: string
          org_id: string
          priority?: number
          purchase_tax_template_id?: string | null
          sales_tax_template_id?: string | null
          shipping_city?: string | null
          shipping_country?: string | null
          shipping_county?: string | null
          shipping_state?: string | null
          shipping_zipcode?: string | null
          supplier_group_id?: string | null
          supplier_id?: string | null
          tax_category_id?: string | null
          tax_type?: string
          to_date?: string | null
          updated_at?: string
          updated_by?: string | null
          use_for_shopping_cart?: boolean
        }
        Update: {
          billing_city?: string | null
          billing_country?: string | null
          billing_county?: string | null
          billing_state?: string | null
          billing_zipcode?: string | null
          company_id?: string
          created_at?: string
          created_by?: string | null
          customer_group_id?: string | null
          customer_id?: string | null
          from_date?: string | null
          id?: string
          item_group_id?: string | null
          item_id?: string | null
          name?: string
          org_id?: string
          priority?: number
          purchase_tax_template_id?: string | null
          sales_tax_template_id?: string | null
          shipping_city?: string | null
          shipping_country?: string | null
          shipping_county?: string | null
          shipping_state?: string | null
          shipping_zipcode?: string | null
          supplier_group_id?: string | null
          supplier_id?: string | null
          tax_category_id?: string | null
          tax_type?: string
          to_date?: string | null
          updated_at?: string
          updated_by?: string | null
          use_for_shopping_cart?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "tax_rule_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "tax_rule_org_id_customer_group_id_fkey"
            columns: ["org_id", "customer_group_id"]
            isOneToOne: false
            referencedRelation: "customer_group"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "tax_rule_org_id_customer_id_fkey"
            columns: ["org_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "customer"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "tax_rule_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tax_rule_org_id_item_group_id_fkey"
            columns: ["org_id", "item_group_id"]
            isOneToOne: false
            referencedRelation: "item_group"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "tax_rule_org_id_item_id_fkey"
            columns: ["org_id", "item_id"]
            isOneToOne: false
            referencedRelation: "item"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "tax_rule_org_id_purchase_tax_template_id_fkey"
            columns: ["org_id", "purchase_tax_template_id"]
            isOneToOne: false
            referencedRelation: "purchase_taxes_and_charges_template"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "tax_rule_org_id_sales_tax_template_id_fkey"
            columns: ["org_id", "sales_tax_template_id"]
            isOneToOne: false
            referencedRelation: "sales_taxes_and_charges_template"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "tax_rule_org_id_supplier_group_id_fkey"
            columns: ["org_id", "supplier_group_id"]
            isOneToOne: false
            referencedRelation: "supplier_group"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "tax_rule_org_id_supplier_id_fkey"
            columns: ["org_id", "supplier_id"]
            isOneToOne: false
            referencedRelation: "supplier"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "tax_rule_org_id_tax_category_id_fkey"
            columns: ["org_id", "tax_category_id"]
            isOneToOne: false
            referencedRelation: "tax_category"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      terms_and_conditions: {
        Row: {
          buying: boolean
          copy_attachments_to_transaction: boolean
          created_at: string
          created_by: string | null
          disabled: boolean
          id: string
          org_id: string
          selling: boolean
          terms: string | null
          title: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          buying?: boolean
          copy_attachments_to_transaction?: boolean
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          org_id: string
          selling?: boolean
          terms?: string | null
          title: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          buying?: boolean
          copy_attachments_to_transaction?: boolean
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          id?: string
          org_id?: string
          selling?: boolean
          terms?: string | null
          title?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "terms_and_conditions_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      territory: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          is_group: boolean
          org_id: string
          parent_id: string | null
          path: unknown
          territory_manager_id: string | null
          territory_name: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_group?: boolean
          org_id: string
          parent_id?: string | null
          path: unknown
          territory_manager_id?: string | null
          territory_name: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_group?: boolean
          org_id?: string
          parent_id?: string | null
          path?: unknown
          territory_manager_id?: string | null
          territory_name?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "territory_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "territory_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "territory"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "territory_org_id_territory_manager_id_fkey"
            columns: ["org_id", "territory_manager_id"]
            isOneToOne: false
            referencedRelation: "sales_person"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      uom: {
        Row: {
          category_id: string | null
          common_code: string | null
          created_at: string
          created_by: string | null
          description: string | null
          enabled: boolean
          id: string
          must_be_whole_number: boolean
          org_id: string
          symbol: string | null
          uom_name: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          category_id?: string | null
          common_code?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          enabled?: boolean
          id?: string
          must_be_whole_number?: boolean
          org_id: string
          symbol?: string | null
          uom_name: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          category_id?: string | null
          common_code?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          enabled?: boolean
          id?: string
          must_be_whole_number?: boolean
          org_id?: string
          symbol?: string | null
          uom_name?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "uom_org_id_category_id_fkey"
            columns: ["org_id", "category_id"]
            isOneToOne: false
            referencedRelation: "uom_category"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "uom_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      uom_category: {
        Row: {
          category_name: string
          created_at: string
          created_by: string | null
          id: string
          org_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          category_name: string
          created_at?: string
          created_by?: string | null
          id?: string
          org_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          category_name?: string
          created_at?: string
          created_by?: string | null
          id?: string
          org_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "uom_category_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      uom_conversion_factor: {
        Row: {
          category: string | null
          created_at: string
          created_by: string | null
          from_uom: string
          id: string
          org_id: string
          to_uom: string
          updated_at: string
          updated_by: string | null
          value: number
        }
        Insert: {
          category?: string | null
          created_at?: string
          created_by?: string | null
          from_uom: string
          id?: string
          org_id: string
          to_uom: string
          updated_at?: string
          updated_by?: string | null
          value: number
        }
        Update: {
          category?: string | null
          created_at?: string
          created_by?: string | null
          from_uom?: string
          id?: string
          org_id?: string
          to_uom?: string
          updated_at?: string
          updated_by?: string | null
          value?: number
        }
        Relationships: [
          {
            foreignKeyName: "uom_conversion_factor_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      uom_conversion_template: {
        Row: {
          category: string
          from_uom: string
          to_uom: string
          value: number
        }
        Insert: {
          category: string
          from_uom: string
          to_uom: string
          value: number
        }
        Update: {
          category?: string
          from_uom?: string
          to_uom?: string
          value?: number
        }
        Relationships: []
      }
      uom_template: {
        Row: {
          category: string | null
          must_be_whole_number: boolean
          uom_name: string
        }
        Insert: {
          category?: string | null
          must_be_whole_number?: boolean
          uom_name: string
        }
        Update: {
          category?: string | null
          must_be_whole_number?: boolean
          uom_name?: string
        }
        Relationships: []
      }
      user_permissions: {
        Row: {
          applicable_for: string | null
          created_at: string
          created_by: string | null
          doctype: string
          hide_descendants: boolean
          id: string
          is_default: boolean
          org_id: string
          record_id: string
          updated_at: string
          updated_by: string | null
          user_id: string
        }
        Insert: {
          applicable_for?: string | null
          created_at?: string
          created_by?: string | null
          doctype: string
          hide_descendants?: boolean
          id?: string
          is_default?: boolean
          org_id: string
          record_id: string
          updated_at?: string
          updated_by?: string | null
          user_id: string
        }
        Update: {
          applicable_for?: string | null
          created_at?: string
          created_by?: string | null
          doctype?: string
          hide_descendants?: boolean
          id?: string
          is_default?: boolean
          org_id?: string
          record_id?: string
          updated_at?: string
          updated_by?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_permissions_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      user_profile: {
        Row: {
          avatar_url: string | null
          created_at: string
          first_name: string | null
          full_name: string | null
          language: string | null
          last_name: string | null
          time_zone: string | null
          updated_at: string
          updated_by: string | null
          user_id: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          first_name?: string | null
          full_name?: string | null
          language?: string | null
          last_name?: string | null
          time_zone?: string | null
          updated_at?: string
          updated_by?: string | null
          user_id: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          first_name?: string | null
          full_name?: string | null
          language?: string | null
          last_name?: string | null
          time_zone?: string | null
          updated_at?: string
          updated_by?: string | null
          user_id?: string
        }
        Relationships: []
      }
      warehouse: {
        Row: {
          account_id: string | null
          address_line_1: string | null
          address_line_2: string | null
          city: string | null
          company_id: string
          created_at: string
          created_by: string | null
          disabled: boolean
          email_id: string | null
          id: string
          is_group: boolean
          is_rejected_warehouse: boolean
          mobile_no: string | null
          name: string
          org_id: string
          parent_id: string | null
          path: unknown
          phone_no: string | null
          pin: string | null
          state: string | null
          updated_at: string
          updated_by: string | null
          warehouse_name: string
          warehouse_type_id: string | null
        }
        Insert: {
          account_id?: string | null
          address_line_1?: string | null
          address_line_2?: string | null
          city?: string | null
          company_id: string
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          email_id?: string | null
          id?: string
          is_group?: boolean
          is_rejected_warehouse?: boolean
          mobile_no?: string | null
          name: string
          org_id: string
          parent_id?: string | null
          path: unknown
          phone_no?: string | null
          pin?: string | null
          state?: string | null
          updated_at?: string
          updated_by?: string | null
          warehouse_name: string
          warehouse_type_id?: string | null
        }
        Update: {
          account_id?: string | null
          address_line_1?: string | null
          address_line_2?: string | null
          city?: string | null
          company_id?: string
          created_at?: string
          created_by?: string | null
          disabled?: boolean
          email_id?: string | null
          id?: string
          is_group?: boolean
          is_rejected_warehouse?: boolean
          mobile_no?: string | null
          name?: string
          org_id?: string
          parent_id?: string | null
          path?: unknown
          phone_no?: string | null
          pin?: string | null
          state?: string | null
          updated_at?: string
          updated_by?: string | null
          warehouse_name?: string
          warehouse_type_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "warehouse_org_id_account_id_fkey"
            columns: ["org_id", "account_id"]
            isOneToOne: false
            referencedRelation: "account"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "warehouse_org_id_company_id_fkey"
            columns: ["org_id", "company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "warehouse_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "warehouse_org_id_parent_id_fkey"
            columns: ["org_id", "parent_id"]
            isOneToOne: false
            referencedRelation: "warehouse"
            referencedColumns: ["org_id", "id"]
          },
          {
            foreignKeyName: "warehouse_org_id_warehouse_type_id_fkey"
            columns: ["org_id", "warehouse_type_id"]
            isOneToOne: false
            referencedRelation: "warehouse_type"
            referencedColumns: ["org_id", "id"]
          },
        ]
      }
      warehouse_type: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          name: string
          org_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          org_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          org_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "warehouse_type_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      coa_template_country: {
        Row: {
          country_name: string | null
          template: string | null
        }
        Relationships: [
          {
            foreignKeyName: "coa_template_file_template_fkey"
            columns: ["template"]
            isOneToOne: false
            referencedRelation: "coa_template"
            referencedColumns: ["name"]
          },
        ]
      }
    }
    Functions: {
      accept_invitation: { Args: { p_token: string }; Returns: string }
      amend_doc: { Args: { p_doctype: string; p_id: string }; Returns: Json }
      cancel_doc: { Args: { p_doctype: string; p_id: string }; Returns: Json }
      card_stock: { Args: { p_filters: Json }; Returns: Json }
      card_sum: {
        Args: { p_doctype: string; p_field: string; p_filters: Json }
        Returns: Json
      }
      chart_account_balance_timeline: {
        Args: { p_filters: Json }
        Returns: Json
      }
      chart_stock: { Args: { p_chart: string; p_filters: Json }; Returns: Json }
      chart_timeseries: {
        Args: {
          p_date_field: string
          p_doctype: string
          p_field: string
          p_filters: Json
          p_interval: string
          p_points: number
        }
        Returns: Json
      }
      coa_template_preview: {
        Args: { p_template: string }
        Returns: {
          account: string
          account_number: string
          account_type: string
          depth: number
          idx: number
          is_group: boolean
          parent_account: string
          root_type: string
        }[]
      }
      coa_templates_for_country: {
        Args: { p_country: string }
        Returns: {
          is_default: boolean
          name: string
        }[]
      }
      company_address: {
        Args: { p_company: string; p_kind?: string }
        Returns: {
          address_line1: string
          address_line2: string | null
          address_title: string | null
          address_type: string
          city: string
          country: string
          county: string | null
          created_at: string
          created_by: string | null
          disabled: boolean
          email_id: string | null
          fax: string | null
          id: string
          is_primary_address: boolean
          is_shipping_address: boolean
          is_your_company_address: boolean
          name: string | null
          org_id: string
          phone: string | null
          pincode: string | null
          state: string | null
          tax_category_id: string | null
          updated_at: string
          updated_by: string | null
        }[]
        SetofOptions: {
          from: "*"
          to: "address"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      copy_item_group_details: { Args: { p_item: string }; Returns: undefined }
      create_company: { Args: { p: Json }; Returns: Json }
      create_default_tax_templates: {
        Args: { p_company: string }
        Returns: undefined
      }
      create_invitation: {
        Args: {
          p_email: string
          p_org: string
          p_role_profile: string
          p_roles: string[]
        }
        Returns: Json
      }
      delete_doc: {
        Args: { p_doctype: string; p_id: string }
        Returns: undefined
      }
      email_sender: {
        Args: { p_account?: string; p_company?: string; p_org: string }
        Returns: {
          add_signature: boolean
          always_use_account_email_id_as_sender: boolean
          always_use_account_name_as_sender_name: boolean
          api_key: string
          email_account_id: string
          email_account_name: string
          email_id: string
          footer: string
          signature: string
        }[]
      }
      get_customer_group_details: {
        Args: { p_customer: string }
        Returns: undefined
      }
      get_exchange_rate: {
        Args: {
          p_date: string
          p_from: string
          p_org: string
          p_side?: string
          p_to: string
        }
        Returns: number
      }
      get_item_details: { Args: { p: Json }; Returns: Json }
      get_item_tax_map: {
        Args: { p_company: string; p_taxes?: Json; p_template: string }
        Returns: Json
      }
      get_outstanding_reference_documents: {
        Args: {
          p_account: string
          p_amount: number
          p_company: string
          p_party: string
          p_party_type: string
        }
        Returns: Json
      }
      get_party_account: {
        Args: { p_company: string; p_party: string; p_party_type: string }
        Returns: string
      }
      get_supplier_group_details: {
        Args: { p_supplier: string }
        Returns: undefined
      }
      get_tax_template: {
        Args: { p_args: Json; p_date: string }
        Returns: string
      }
      import_uoms: { Args: { p_org: string }; Returns: number }
      invitation_preview: { Args: { p_token: string }; Returns: Json }
      make_stock_entry_from_material_request: {
        Args: { p_id: string }
        Returns: Json
      }
      material_request_set_status: {
        Args: { p_id: string; p_status: string }
        Returns: Json
      }
      onboarding_dismiss: { Args: { p_org: string }; Returns: undefined }
      onboarding_skip: {
        Args: { p_org: string; p_step: string }
        Returns: undefined
      }
      org_member_directory: {
        Args: { p_org: string }
        Returns: {
          avatar_url: string
          created_at: string
          email: string
          full_name: string
          is_owner: boolean
          last_sign_in_at: string
          role_profile: string
          roles: string[]
          status: string
          user_id: string
        }[]
      }
      party_addresses: {
        Args: { p_doctype: string; p_id: string }
        Returns: {
          address_line1: string
          address_line2: string | null
          address_title: string | null
          address_type: string
          city: string
          country: string
          county: string | null
          created_at: string
          created_by: string | null
          disabled: boolean
          email_id: string | null
          fax: string | null
          id: string
          is_primary_address: boolean
          is_shipping_address: boolean
          is_your_company_address: boolean
          name: string | null
          org_id: string
          phone: string | null
          pincode: string | null
          state: string | null
          tax_category_id: string | null
          updated_at: string
          updated_by: string | null
        }[]
        SetofOptions: {
          from: "*"
          to: "address"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      party_contacts: {
        Args: { p_doctype: string; p_id: string }
        Returns: {
          address_id: string | null
          company_name: string | null
          created_at: string
          created_by: string | null
          department: string | null
          designation_id: string | null
          email_id: string | null
          first_name: string
          full_name: string | null
          gender: string | null
          id: string
          image: string | null
          is_billing_contact: boolean
          is_primary_contact: boolean
          last_name: string | null
          middle_name: string | null
          mobile_no: string | null
          name: string | null
          org_id: string
          phone: string | null
          salutation: string | null
          status: string
          unsubscribed: boolean
          updated_at: string
          updated_by: string | null
          user_id: string | null
        }[]
        SetofOptions: {
          from: "*"
          to: "contact"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      permission_doctypes: {
        Args: never
        Returns: {
          doctype: string
          is_submittable: boolean
          locked: boolean
          module: string
        }[]
      }
      provision_organization: { Args: { p: Json }; Returns: Json }
      report_balance_sheet: { Args: { p_filters: Json }; Returns: Json }
      report_cash_flow: { Args: { p_filters: Json }; Returns: Json }
      report_general_ledger: { Args: { p_filters: Json }; Returns: Json }
      report_profit_and_loss: { Args: { p_filters: Json }; Returns: Json }
      report_stock_ageing: { Args: { p_filters: Json }; Returns: Json }
      report_stock_balance: { Args: { p_filters: Json }; Returns: Json }
      report_stock_ledger: { Args: { p_filters: Json }; Returns: Json }
      report_stock_projected_qty: { Args: { p_filters: Json }; Returns: Json }
      report_trial_balance: { Args: { p_filters: Json }; Returns: Json }
      report_trial_balance_for_party: {
        Args: { p_filters: Json }
        Returns: Json
      }
      resend_invitation: { Args: { p_id: string }; Returns: Json }
      reset_role_permissions: {
        Args: { p_doctype: string; p_org: string }
        Returns: number
      }
      sanitize_html: { Args: { p_html: string }; Returns: string }
      save_doc: { Args: { p_doctype: string; p_payload: Json }; Returns: Json }
      search_link: {
        Args: {
          p_doctype: string
          p_ids?: string[]
          p_org: string
          p_q?: string
        }
        Returns: {
          id: string
          label: string
        }[]
      }
      set_email_account_key: {
        Args: { p_id: string; p_secret: string }
        Returns: undefined
      }
      submit_doc: { Args: { p_doctype: string; p_id: string }; Returns: Json }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  app: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const
