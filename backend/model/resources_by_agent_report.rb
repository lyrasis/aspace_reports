class ResourcesByAgentReport < AbstractReport
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
                      "resource.create_time >=
                      #{db.literal(@from.split(' ')[0].gsub('-', ''))} 
                      and resource.create_time <=
                      #{db.literal(@to.split(' ')[0].gsub('-', ''))}"
                    else
                      '1=1'
                    end
    "SELECT resource.id as resource_system_id, 
      resource.identifier as resource_number, resource.title as Title, ifnull(ifnull(ifnull(name_person.sort_name, name_family.sort_name), name_corporate_entity.sort_name), 'Unknown') as name
      FROM resource
      LEFT OUTER JOIN linked_agents_rlshp ON (resource.id = linked_agents_rlshp.resource_id)
      left outer join name_person
        on name_person.agent_person_id = linked_agents_rlshp.agent_person_id
      left outer join name_family
        on name_family.agent_family_id = linked_agents_rlshp.agent_family_id
      left outer join name_corporate_entity
        on name_corporate_entity.agent_corporate_entity_id = 
        linked_agents_rlshp.agent_corporate_entity_id
      WHERE repo_id = #{db.literal(@repo_id)} AND #{date_condition}
      ORDER BY resource.create_time DESC"
  end

  def fix_row(row)
    ReportUtils.fix_identifier_format(row, :resource_number)
    row[:date] = ResourcesListDatesSubreport.new(self, row[:resource_system_id]).get_content
		row[:extent] = ExtentSubreport.new(self, row[:resource_system_id]).get_content
    row.delete(:resource_system_id)
  end

	def record_type
		'resource'
	end

end
