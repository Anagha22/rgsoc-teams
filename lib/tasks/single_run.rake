namespace :single_run do
  desc '2015-04-06: Migrate data entered into Teams#description to ApplicationDraft#project_plan'
  task copy_team_description_to_application_draft: :environment do
    ApplicationDraft.includes(:team).each do |draft|
      draft.update_attribute(:project_plan, draft.team.description) if draft.team
    end
  end

  desc '2017-03-07: Remap ApplicationDraft and Application Projects to the ones from the current season'
  task remap_application_projects_to_current_season: :environment do
    in_wrong_season = ->(prj) { prj && prj.season.name != '2017' }

    ApplicationDraft.in_current_season.includes(project1: :season, project2: :season).each do |draft|
      if in_wrong_season.(draft.project1)
        project = Project.in_current_season.find_by(name: draft.project1.name)
        draft.project1 = project
        draft.save(validate: false)

        if app = draft.application
          app.application_data["project1_id"] = project.id.to_s
          app.save(validate: false)
        end
      end

      if in_wrong_season.(draft.project2)
        project = Project.in_current_season.find_by(name: draft.project2.name)
        draft.project2 = project
        draft.save(validate: false)

        if app = draft.application
          app.application_data["project2_id"] = project.id.to_s
          app.save(validate: false)
        end
      end
    end
  end

  desc '2017-03-20: Remap mentor sign-offs to the right project'
  task remap_mentor_sign_offs_to_the_right_project: :environment do
    applications = Application
      .where(season: Season.current)
      .where.not(team: nil, signed_off_at: nil)

    applications.find_each do |application|
      project1_id = application.application_data['project1_id'].to_i
      mentor_id   = application.signed_off_by
      project_ids = Project.in_current_season.where(submitter_id: mentor_id).ids
      choice      = project_ids.include?(project1_id) ? 1 : 2

      application.application_data["signed_off_at_project#{choice}"] = application.signed_off_at
      application.application_data["signed_off_by_project#{choice}"] = mentor_id
      application.save
    end
  end
end
