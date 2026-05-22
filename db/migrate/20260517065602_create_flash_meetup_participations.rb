class CreateFlashMeetupParticipations < ActiveRecord::Migration[8.1]
  def change
    create_table :flash_meetup_participations do |t|
      t.references :flash_meetup, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    # 동일 모임에 동일 사용자가 confirmed/waitlisted 상태로 중복 신청 불가
    # cancelled(2)는 제외 — partial unique index
    add_index :flash_meetup_participations,
              [ :flash_meetup_id, :user_id ],
              unique: true,
              where: "status != 2",
              name: "idx_flash_meetup_participations_unique_active"
  end
end
