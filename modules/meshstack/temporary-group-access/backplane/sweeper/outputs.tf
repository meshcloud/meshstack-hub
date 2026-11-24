output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = length(local.expired) == 0 ? "No expired temporary group access to delete." : <<-EOT
    # Expired temporary group access

    | Building block | Workspace | Expired at |
    |---|---|---|
    %{for uuid, bb in local.expired~}
    | ${bb.display_name} (`${uuid}`) | `${bb.workspace}` | ${bb.expires_at} |
    %{endfor~}
  EOT
}
