# frozen_string_literal: true

# Client to access the aker-projects-app API
module StudyClient
  # Returns a list of unique projects where the given user has spend permissions
  # either as an individual or a member of a group, in projects-app.
  # Unique as a project might have been created by the user (therefor has spend permission)
  # and be a member of a group with spend permissions.
  def self.get_spendable_projects(user)
    StudyClient::Node.where(
      node_type: 'subproject',
      with_parent_spendable_by: user_and_groups_list(user)
    ).all.uniq(&:id)
  end

  # Returns a boolean whether the current user has spend permisssion on the given project id
  def self.current_user_has_spend_permission_on_project(project_id)
    StudyClient::Node.where(id: project_id).all[0]['spendable-by-current-user']
  end

  def self.user_and_groups_list(current_user)
    [current_user.email] + current_user.groups
  end
end
