class AccessionsByAgentReport < AbstractReport
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
                      "accession_date > 
                      #{db.literal(@from.split(' ')[0].gsub('-', ''))} 
                      and accession_date < 
                      #{db.literal(@to.split(' ')[0].gsub('-', ''))}"
                    else
                      '1=1'
                    end
    "SELECT accession.id as accession_system_id, 
      accession.identifier as accession_number, accession.title as Title, accession.create_time, extent_number, extent_type
      FROM accession
      LEFT JOIN linked_agents_rlshp ON (accession.id = linked_agents_rlshp.accession_id)
      natural left outer join
        (select
          accession_id,
          sum(number) as extent_number,
          GROUP_CONCAT(distinct extent_type_id SEPARATOR ', ') as extent_type
        from extent
        group by accession_id) as extent_cnt
      WHERE repo_id = #{db.literal(@repo_id)} AND #{date_condition}
        AND linked_agents_rlshp.accession_id IS NOT NULL
      ORDER BY accession.create_time DESC"
  end

  def fix_row(row)
    ReportUtils.fix_identifier_format(row, :accession_number)
    ReportUtils.get_enum_values(row, [:extent_type])
    ReportUtils.fix_extent_format(row)
    row[:names] = AccessionNamesSubreport.new(self, row[:accession_system_id]).get_content
    row.delete(:accession_system_id)
  end

  def identifier_field
    :accession_number
  end

end
