module Admin
  class DataManagementController < BaseController
    def show
      authorize :data_management, policy_class: Admin::DataManagementPolicy
      @database_backups = Admin::DatabaseBackups::ListService.call
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

    def create_backup
      authorize :data_management, policy_class: Admin::DataManagementPolicy

      result = Admin::DatabaseBackups::CreateService.call(
        user: current_user,
        include_sql_dump: params[:include_sql_dump] == "1"
      )

      if result.success?
        redirect_to admin_data_management_path(anchor: "db-backups"),
                    notice: "DB 백업을 생성했습니다."
      else
        redirect_to admin_data_management_path(anchor: "db-backups"),
                    alert: "DB 백업 생성에 실패했습니다: #{result.error}"
      end
    end

    def download_backup
      authorize :data_management, policy_class: Admin::DataManagementPolicy

      result = Admin::DatabaseBackups::DownloadPathService.call(
        backup_id: params[:id],
        filename: params[:file]
      )

      if result.success?
        send_file result.path, filename: result.filename, type: result.content_type, disposition: "attachment"
      else
        redirect_to admin_data_management_path(anchor: "db-backups"), alert: result.error
      end
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
