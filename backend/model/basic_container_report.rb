class BasicContainerReport < AbstractReport
  register_report

  # TODO: add top container note field
  # https://github.com/archivesspace/archivesspace/pull/2800
  def query_string
    "
      SELECT identifier, top_container_barcode, type, indicator, location_barcode FROM (
        SELECT
          (json_unquote(resource.identifier->'$[0]')) AS identifier,
          top_container.barcode AS top_container_barcode,
          enumeration_value.value AS type,
          top_container.indicator,
          location.barcode AS location_barcode
        FROM top_container
          LEFT JOIN enumeration_value ON (top_container.type_id = enumeration_value.id)
          LEFT JOIN top_container_housed_at_rlshp ON (top_container.id = top_container_housed_at_rlshp.top_container_id)
          LEFT JOIN location ON (location.id = top_container_housed_at_rlshp.location_id)
          LEFT JOIN top_container_link_rlshp ON (top_container.id = top_container_link_rlshp.top_container_id)
          LEFT JOIN sub_container ON (top_container_link_rlshp.sub_container_id = sub_container.id)
          LEFT JOIN instance ON (sub_container.instance_id = instance.id)
          INNER JOIN archival_object ON (instance.archival_object_id = archival_object.id)
          LEFT JOIN resource ON (archival_object.root_record_id = resource.id)
        WHERE resource.repo_id = #{db.literal(@repo_id)}
        UNION
        SELECT
          (json_unquote(resource.identifier->'$[0]')) AS identifier,
          top_container.barcode AS top_container_barcode,
          enumeration_value.value AS type,
          top_container.indicator,
          location.barcode AS location_barcode
        FROM top_container
          LEFT JOIN enumeration_value ON (top_container.type_id = enumeration_value.id)
          LEFT JOIN top_container_housed_at_rlshp ON (top_container.id = top_container_housed_at_rlshp.top_container_id)
          LEFT JOIN location ON (location.id = top_container_housed_at_rlshp.location_id)
          LEFT JOIN top_container_link_rlshp ON (top_container.id = top_container_link_rlshp.top_container_id)
          LEFT JOIN sub_container ON (top_container_link_rlshp.sub_container_id = sub_container.id)
          LEFT JOIN instance ON (sub_container.instance_id = instance.id)
          INNER JOIN resource ON (instance.resource_id = resource.id)
        WHERE resource.repo_id = #{db.literal(@repo_id)}
      ) AS basic_container_report
      ORDER BY identifier, type, indicator;
    "
  end

  def identifier_field
    :identifier
  end

  def page_break
    false
  end
end
