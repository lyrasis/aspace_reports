class FamilyNamesByResourceReport < AbstractReport
  register_report

  def query_string
    "SELECT agent_family.id as family_system_id,
      name_family.sort_name as name,
      resource.identifier as resource_number, resource.title as resource_title
      FROM agent_family
      JOIN name_family
        ON name_family.agent_family_id = agent_family.id
        AND name_family.is_display_name = 1
      LEFT OUTER JOIN (
        linked_agents_rlshp
        JOIN resource
          ON resource.id = linked_agents_rlshp.resource_id
          AND resource.repo_id = #{db.literal(@repo_id)}
      ) ON linked_agents_rlshp.agent_family_id = agent_family.id
      ORDER BY name_family.sort_name, resource.identifier"
  end

  def fix_row(row)
    ReportUtils.fix_identifier_format(row, :resource_number)
    row.delete(:family_system_id)
  end

  def identifier_field
    :name
  end

  def record_type
    'agent_family'
  end

end
