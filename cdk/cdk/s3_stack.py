from aws_cdk import (
    Stack,
    aws_s3 as s3,
    Tags,
)
from constructs import Construct

class S3Stack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        Tags.of(self).add("IaC", "true")

        tofu_state = s3.Bucket(self, "s3",
            bucket_name=f"{construct_id}",
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            versioned=True
        )

