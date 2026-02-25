class DetailedResourceInstancesListReport < AbstractReport
  register_report

  def query_string
    "SELECT
      tc.indicator AS indicator,
      tc.barcode AS barcode,
      MAX(ev_type.value) AS container_type,
      MAX(cp.name) AS container_profile,
      res.identifier AS resource_id,
      MAX(res.title) AS resource_title,
      GROUP_CONCAT(DISTINCT loc.title SEPARATOR '; ') AS location,
      # New: Collect all Series titles and CUIDs linked to this box
      GROUP_CONCAT(DISTINCT CASE WHEN ao_series.level_id = (SELECT id FROM enumeration_value WHERE value = 'series') THEN ao_series.display_string END SEPARATOR '; ') AS series_title,
      GROUP_CONCAT(DISTINCT CASE WHEN ao_series.level_id = (SELECT id FROM enumeration_value WHERE value = 'series') THEN ao_series.component_id END SEPARATOR '; ') AS series_cuid
    FROM top_container tc
    LEFT OUTER JOIN enumeration_value ev_type ON (ev_type.id = tc.type_id)
    LEFT OUTER JOIN top_container_profile_rlshp tcpr ON (tcpr.top_container_id = tc.id)
    LEFT OUTER JOIN container_profile cp ON (cp.id = tcpr.container_profile_id)
    
    # Link to Resources
    LEFT OUTER JOIN top_container_link_rlshp tclr ON (tclr.top_container_id = tc.id)
    LEFT OUTER JOIN sub_container sc ON (sc.id = tclr.sub_container_id)
    LEFT OUTER JOIN instance inst ON (inst.id = sc.instance_id)
    LEFT OUTER JOIN archival_object ao ON (ao.id = inst.archival_object_id)
    LEFT OUTER JOIN resource res ON (res.id = ao.root_record_id OR res.id = inst.resource_id)
    
    # Logic to find the Series-level parent for the Archival Object
    # This traverses up the tree to find the record marked as 'series'
    LEFT OUTER JOIN archival_object ao_series ON (
      ao_series.root_record_id = res.id AND 
      (ao_series.id = ao.id OR ao_series.id = (
        SELECT parent.id FROM archival_object parent 
        WHERE ao.parent_id IS NOT NULL 
        AND parent.id = ao.parent_id 
        AND parent.level_id = (SELECT id FROM enumeration_value WHERE value = 'series')
      ))
    )
    
    LEFT OUTER JOIN top_container_housed_at_rlshp tch ON (tch.top_container_id = tc.id)
    LEFT OUTER JOIN location loc ON (loc.id = tch.location_id)
    
    WHERE tc.repo_id = #{db.literal(@repo_id)}
    GROUP BY tc.id, res.id
    ORDER BY 
      CASE WHEN res.identifier IS NULL THEN 1 ELSE 0 END, 
      res.identifier, 
      LENGTH(tc.indicator), 
      tc.indicator"
  end

  def fix_row(row)
    row[:barcode] = row[:barcode].to_s if row[:barcode]
    row[:resource_id] = format_identifier(row[:resource_id])
    
    # Ensure Series data doesn't return as nil
    [:container_type, :container_profile, :resource_title, :location, :series_title, :series_cuid].each do |field|
      row[field] ||= ""
    end
  end

  def format_identifier(id_json)
    return "" if id_json.nil?
    begin
      JSON.parse(id_json).compact.join('.')
    rescue
      id_json.to_s
    end
  end

  def identifier_field
    :barcode
  end
end
