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
      custom_access_token_hook: { Args: { event: Json }; Returns: Json }
      has_perm: {
        Args: { p_action: string; p_doctype: string; p_org: string }
        Returns: boolean
      }
      has_role: { Args: { p_org: string; p_role: string }; Returns: boolean }
      is_member: { Args: { p_org: string }; Returns: boolean }
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
      user_org_ids: { Args: never; Returns: string[] }
      user_roles: { Args: { p_org: string }; Returns: string[] }
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
      doctype_meta: {
        Row: {
          allow_on_submit: string[]
          doctype: string
          is_child: boolean
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
          doctype: string
          is_child?: boolean
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
          doctype?: string
          is_child?: boolean
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
        Relationships: []
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
