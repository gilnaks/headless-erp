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
      accept_invitation: { Args: { p_token: string }; Returns: string }
      address_refresh: { Args: { p_address: string }; Returns: undefined }
      allowed_records: {
        Args: { p_doctype: string; p_for?: string; p_org: string }
        Returns: string[]
      }
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
      coa_account_categories: { Args: { p_tree: Json }; Returns: string[] }
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
      copy_uoms: { Args: { p_all: boolean; p_org: string }; Returns: undefined }
      create_company: { Args: { p: Json }; Returns: Json }
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
      jsonb_pick: { Args: { p: Json; p_keys: string[] }; Returns: Json }
      locked_permission_doctypes: { Args: never; Returns: string[] }
      next_name: {
        Args: {
          p_company: string
          p_org: string
          p_posting_date?: string
          p_series: string
        }
        Returns: string
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
      resend_invitation: { Args: { p_id: string }; Returns: Json }
      reserved_slugs: { Args: never; Returns: string[] }
      reset_role_permissions: {
        Args: { p_doctype: string; p_org: string }
        Returns: number
      }
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
      seed_customer_groups: { Args: { p_org: string }; Returns: undefined }
      seed_department_root: { Args: { p_org: string }; Returns: string }
      seed_departments: { Args: { p_company: string }; Returns: undefined }
      seed_designations: { Args: { p_org: string }; Returns: undefined }
      seed_item_groups: { Args: { p_org: string }; Returns: undefined }
      seed_onboarding: { Args: { p_org: string }; Returns: undefined }
      seed_print_formats: {
        Args: { p_doctype?: string; p_org: string }
        Returns: undefined
      }
      seed_sales_persons: { Args: { p_org: string }; Returns: undefined }
      seed_stock_entry_types: { Args: { p_org: string }; Returns: undefined }
      seed_supplier_groups: { Args: { p_org: string }; Returns: undefined }
      seed_territories: { Args: { p_org: string }; Returns: undefined }
      seed_uoms: { Args: { p_org: string }; Returns: undefined }
      set_email_account_key: {
        Args: { p_id: string; p_secret: string }
        Returns: undefined
      }
      sync_role_permissions: { Args: { p_org?: string }; Returns: undefined }
      tree_label: { Args: { p_id: string }; Returns: unknown }
      uom_names_curated: { Args: never; Returns: string[] }
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
            foreignKeyName: "companies_chart_of_accounts_fkey"
            columns: ["chart_of_accounts"]
            isOneToOne: false
            referencedRelation: "coa_template"
            referencedColumns: ["name"]
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
            foreignKeyName: "companies_reporting_currency_fkey"
            columns: ["reporting_currency"]
            isOneToOne: false
            referencedRelation: "currency"
            referencedColumns: ["code"]
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
      customer_group: {
        Row: {
          created_at: string
          created_by: string | null
          customer_group_name: string
          id: string
          is_group: boolean
          org_id: string
          parent_id: string | null
          path: unknown
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          customer_group_name: string
          id?: string
          is_group?: boolean
          org_id: string
          parent_id?: string | null
          path: unknown
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          customer_group_name?: string
          id?: string
          is_group?: boolean
          org_id?: string
          parent_id?: string | null
          path?: unknown
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
      supplier_group: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          is_group: boolean
          org_id: string
          parent_id: string | null
          path: unknown
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
      create_company: { Args: { p: Json }; Returns: Json }
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
      import_uoms: { Args: { p_org: string }; Returns: number }
      invitation_preview: { Args: { p_token: string }; Returns: Json }
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
