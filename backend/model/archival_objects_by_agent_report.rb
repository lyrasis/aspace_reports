class ArchivalObjectsByAgentReport < AbstractReport
  register_report(
    params: [['scope_by_date', 'Boolean', 'Scope records by a date range'],
             ['from', Date, 'The start of report range'],
             ['to', Date, 'The start of report range']]
  )

  def initialize(params, job, db)
    super

    @date_scope = params['scope_by_date']

    if @date_scope
      from = params['from']
      to = params['to']

      raise 'Date range not specified.' if from === '' || to === ''

      @from = DateTime.parse(from).to_time.strftime('%Y-%m-%d %H:%M:%S')
      @to = DateTime.parse(to).to_time.strftime('%Y-%m-%d %H:%M:%S')

      info[:scoped_by_date_range] = "#{@from} & #{@to}"
    end
  end

  def query_string
    date_condition = if @date_scope
                      "archival_object.create_time > 
                      #{db.literal(@from.split(' ')[0].gsub('-', ''))} 
                      and archival_object.create_time < 
                      #{db.literal(@to.split(' ')[0].gsub('-', ''))}"
                    else
                      '1=1'
                    end
    "SELECT archival_object.id as archival_object_system_id, 
      archival_object.component_id, archival_object.title as Title, archival_object.create_time, extent_number, extent_type, ifnull(ifnull(ifnull(name_person.sort_name, name_family.sort_name), name_corporate_entity.sort_name), 'Unknown') as name, role_id as `function`, relator_id as role
      FROM archival_object
      LEFT JOIN linked_agents_rlshp ON (archival_object.id = linked_agents_rlshp.archival_object_id)
      left outer join name_person
        on name_person.agent_person_id = linked_agents_rlshp.agent_person_id
      left outer join name_family
        on name_family.agent_family_id = linked_agents_rlshp.agent_family_id
      left outer join name_corporate_entity
        on name_corporate_entity.agent_corporate_entity_id = 
        linked_agents_rlshp.agent_corporate_entity_id
      natural left outer join
        (select
          archival_object_id,
          sum(number) as extent_number,
          GROUP_CONCAT(distinct extent_type_id SEPARATOR ', ') as extent_type
        from extent
        group by archival_object_id) as extent_cnt
      WHERE repo_id = #{db.literal(@repo_id)} AND #{date_condition}
        AND linked_agents_rlshp.archival_object_id IS NOT NULL
      ORDER BY archival_object.create_time DESC"
  end

  def fix_row(row)
    ReportUtils.get_enum_values(row, [:extent_type, :function, :role])
    ReportUtils.fix_extent_format(row)
    row.delete(:archival_object_system_id)
  end

end
