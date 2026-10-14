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
      allowed_records: {
        Args: { p_doctype: string; p_for?: string; p_org: string }
        Returns: string[]
      }
      company_allowed: {
        Args: { p_company: string; p_for?: string; p_org: string }
        Returns: boolean
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
      enable_org_currency: {
        Args: { p_code: string; p_org: string }
        Returns: undefined
      }
      has_perm: {
        Args: { p_action: string; p_doctype: string; p_org: string }
        Returns: boolean
      }
      has_role: { Args: { p_org: string; p_role: string }; Returns: boolean }
      is_member: { Args: { p_org: string }; Returns: boolean }
      jsonb_pick: { Args: { p: Json; p_keys: string[] }; Returns: Json }
      next_name: {
        Args: {
          p_company: string
          p_org: string
          p_posting_date?: string
          p_series: string
        }
        Returns: string
      }
      orgs_with_perm: {
        Args: { p_action: string; p_doctype: string }
        Returns: string[]
      }
      orgs_with_role: { Args: { p_role: string }; Returns: string[] }
      record_allowed: {
        Args: {
          p_doctype: string
          p_for?: string
          p_org: string
          p_record: string
        }
        Returns: boolean
      }
      reserved_slugs: { Args: never; Returns: string[] }
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
      sync_role_permissions: { Args: { p_org?: string }; Returns: undefined }
      tree_label: { Args: { p_id: string }; Returns: unknown }
      user_org_ids: { Args: never; Returns: string[] }
      user_roles: { Args: { p_org: string }; Returns: string[] }
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
      doctype_meta: {
        Row: {
          allow_on_submit: string[]
          child_field: string | null
          doctype: string
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
          name: string
          org_id: string
          roles: string[]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          name: string
          org_id: string
          roles?: string[]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
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
      [_ in never]: never
    }
    Functions: {
      accept_invitation: { Args: { p_token: string }; Returns: string }
      create_organization: { Args: { p: Json }; Returns: Json }
      delete_doc: {
        Args: { p_doctype: string; p_id: string }
        Returns: undefined
      }
      save_doc: { Args: { p_doctype: string; p_payload: Json }; Returns: Json }
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
