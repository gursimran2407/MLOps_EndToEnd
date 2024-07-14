resource "aws_sagemaker_project" "mlops_project" {
  project_name        = "mlops-pipeline-project"
  project_description = "End-to-end MLOps pipeline for model training and deployment"
}
