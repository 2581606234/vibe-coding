# Use soft deletion and local Recovery Points for recoverability

VibePM will represent deletion by recording a deletion date and deletion-batch identity on Projects and Tasks. Active queries exclude those records; Trash can restore a complete batch or permanently delete it. Automatic and pre-import Recovery Points are JSON snapshots stored locally and retained independently from Excel exchange files.

This preserves stable record identities and relationships during recovery, keeps Archive semantically separate from Trash, and makes destructive actions reversible without requiring a cloud service. The trade-off is additional filtering and lifecycle logic on every task/project query, plus explicit cleanup of expired Trash and old Recovery Points.
