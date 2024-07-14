resource "aws_codebuild_project" "model_deploy" {
  name         = "sagemaker-model-deploy"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "CODEPIPELINE"
  }
}

resource "aws_codepipeline" "model_deploy_pipeline" {
  name     = "sagemaker-model-deploy-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_codecommit_repository.ml_repo.repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.model_deploy.name
      }
    }
  }

  stage {
    name = "DeployToStaging"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ActionMode    = "CREATE_UPDATE"
        StackName     = "SageMakerStagingStack"
        TemplatePath  = "source_output::template.yaml"
        Capabilities  = "CAPABILITY_IAM"
        RoleArn       = aws_iam_role.cloudformation_role.arn
      }
    }
  }

  stage {
    name = "ApprovalStage"

    action {
      name     = "Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  stage {
    name = "DeployToProduction"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ActionMode    = "CREATE_UPDATE"
        StackName     = "SageMakerProductionStack"
        TemplatePath  = "source_output::template.yaml"
        Capabilities  = "CAPABILITY_IAM"
        RoleArn       = aws_iam_role.cloudformation_role.arn
      }
    }
  }
}


resource "aws_sagemaker_model" "model" {
  name               = "my-sagemaker-model"
  execution_role_arn = aws_iam_role.sagemaker_role.arn

  primary_container {
    image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/my-sagemaker-model:latest"
  }
}

resource "aws_sagemaker_endpoint_configuration" "staging_config" {
  name = "staging-endpoint-config"

  production_variants {
    variant_name           = "variant-1"
    model_name             = aws_sagemaker_model.model.name
    initial_instance_count = 1
    instance_type          = "ml.t2.medium"
  }
}

resource "aws_sagemaker_endpoint" "staging_endpoint" {
  name                 = "staging-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.staging_config.name
}

resource "aws_sagemaker_endpoint_configuration" "prod_config" {
  name = "prod-endpoint-config"

  production_variants {
    variant_name           = "variant-1"
    model_name             = aws_sagemaker_model.model.name
    initial_instance_count = 2
    instance_type          = "ml.c5.large"
  }
}

resource "aws_sagemaker_endpoint" "prod_endpoint" {
  name                 = "prod-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.prod_config.name
}

## After the model is built, we'll register it in a Model Package Group:
resource "aws_sagemaker_model_package_group" "model_package_group" {
  model_package_group_name        = "my-model-package-group"
  model_package_group_description = "Model package group for our MLOps pipeline"
}
