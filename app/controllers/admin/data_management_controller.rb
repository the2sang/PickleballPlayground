module Admin
  class DataManagementController < BaseController
    def show
      authorize :data_management, policy_class: Admin::DataManagementPolicy
    end

    def execute
      authorize :data_management, policy_class: Admin::DataManagementPolicy

      sql = params[:sql].to_s.strip

      if sql.blank?
        render json: { error: "SQL을 입력해 주세요." }, status: :bad_request and return
      end

      Rails.logger.info "[DataManagement] User #{current_user.id} (#{current_user.email_address}) executed: #{sql}"

      render json: run_sql(sql)
    end

    private

    def run_sql(sql)
      conn = ActiveRecord::Base.connection

      if sql.match?(/\A\s*SELECT/i)
        result = conn.select_all(sql) # brakeman:ignore:SQL
        {
          type:      "select",
          columns:   result.columns,
          rows:      result.rows,
          row_count: result.length
        }
      else
        conn.execute(sql) # brakeman:ignore:SQL
        affected = conn.raw_connection.changes
        {
          type:          "dml",
          affected_rows: affected,
          message:       "#{affected}행이 변경되었습니다."
        }
      end
    rescue => e
      { type: "error", error: e.message }
    end
  end
end
