class RepositoryMismatchReport < AbstractReport
  register_report

  # Finds archival objects left in the wrong repository by a transfer or move
  # that failed partway. Checks the whole database, not only the current
  # repository, because a mismatch always spans two repositories.
  def query_string
    "
      SELECT problem, archival_object_id, ref_id, ao_title, ao_repository, expected_repository, related_record_id FROM (
        SELECT
          'AO repository does not match its resource' AS problem,
          ao.id AS archival_object_id,
          ao.ref_id,
          ao.title AS ao_title,
          ao_repo.repo_code AS ao_repository,
          r_repo.repo_code AS expected_repository,
          CONCAT('resource ', r.id) AS related_record_id
        FROM archival_object ao
          JOIN resource r ON (ao.root_record_id = r.id)
          JOIN repository ao_repo ON (ao.repo_id = ao_repo.id)
          JOIN repository r_repo ON (r.repo_id = r_repo.id)
        WHERE ao.repo_id != r.repo_id
        UNION ALL
        SELECT
          'AO repository does not match its parent AO' AS problem,
          ao.id AS archival_object_id,
          ao.ref_id,
          ao.title AS ao_title,
          ao_repo.repo_code AS ao_repository,
          p_repo.repo_code AS expected_repository,
          CONCAT('archival_object ', parent.id) AS related_record_id
        FROM archival_object ao
          JOIN archival_object parent ON (ao.parent_id = parent.id)
          JOIN repository ao_repo ON (ao.repo_id = ao_repo.id)
          JOIN repository p_repo ON (parent.repo_id = p_repo.id)
        WHERE ao.repo_id != parent.repo_id
      ) AS repository_mismatch_report
      ORDER BY problem, archival_object_id;
    "
  end

  def page_break
    false
  end
end
