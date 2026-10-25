output "workspace_ids" {
  description = "Workspace name to ID."
  value       = { for ws in tfe_workspace.this : ws.name => ws.id }
}

output "project_ids" {
  description = "Project name to ID."
  value       = { for p in tfe_project.this : p.name => p.id }
}
