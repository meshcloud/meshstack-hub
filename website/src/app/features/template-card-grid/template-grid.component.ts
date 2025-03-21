import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { Template } from '../../core';
import { CardComponent } from '../../shared/card/card.component';

@Component({
  selector: 'app-template-grid',
  imports: [CommonModule, CardComponent],
  templateUrl: './template-grid.component.html',
  styleUrl: './template-grid.component.scss',
  standalone: true
})
export class TemplateOverviewComponent implements OnInit {

  public templates: Template[] = [
    { id: 'azure-storage', icon: 'https://www.meshcloud.io/wp-content/uploads/meshStack-OG-w-White-Text-on-Blue-.png', name: 'Azure Storage', description: 'Highly scalable and secure cloud storage solution by Microsoft Azure.', type: 'AZURE' },
    { id: 'azure-functions', icon: 'https://www.meshcloud.io/wp-content/uploads/meshStack-OG-w-White-Text-on-Blue-.png', name: 'Azure Functions', description: 'Event-driven serverless compute platform by Azure.', type: 'AZURE' },
    { id: 'aws-s3', icon: 'https://www.meshcloud.io/wp-content/uploads/meshStack-OG-w-White-Text-on-Blue-.png', name: 'AWS S3', description: 'Object storage service offering industry-leading scalability by AWS.', type: 'AWS' },
    { id: 'aws-lambda', icon: 'https://lh4.googleusercontent.com/3EzZIeXjlJ_GvGt3EJ7SmdkAqhWb0qma6moFNmHnnulDzXokaixtt4fmr88cUYstT6vvQrBayu0c14bH1kRwg6YEl9OKbWQrzDbx2PxmH90aJuEpUn7iYHWyGp2rZrAUTA=w1280', name: 'AWS Lambda', description: 'Run code without provisioning or managing servers by AWS.', type: 'AWS' },
    { id: 'gcp-compute-engine', icon: 'https://www.meshcloud.io/wp-content/uploads/meshStack-OG-w-White-Text-on-Blue-.png', name: 'GCP Compute Engine', description: 'Scalable, high-performance virtual machines by Google Cloud.', type: 'GCP' },
    { id: 'gcp-bigquery', icon: 'https://www.meshcloud.io/wp-content/uploads/meshStack-OG-w-White-Text-on-Blue-.png', name: 'GCP BigQuery', description: 'Serverless, highly scalable, and cost-effective data warehouse by Google Cloud.', type: 'GCP' },
    { id: 's3-bucket', icon: 'https://www.meshcloud.io/wp-content/uploads/meshStack-OG-w-White-Text-on-Blue-.png', name: 'S3 Bucket', description: 'Generic object storage for various cloud providers.', type: 'AWS' },
    { id: 'kubernetes-cluster', icon: 'https://www.meshcloud.io/wp-content/uploads/meshStack-OG-w-White-Text-on-Blue-.png', name: 'Kubernetes Cluster', description: 'Generic container orchestration platform for managing workloads.', type: 'AWS' }
  ];

  public filteredTemplates: Template[] = [];

  constructor(private route: ActivatedRoute) {}

  public ngOnInit(): void {
    this.route.paramMap.subscribe(params => {
      const type = params.get('type')?.toLocaleUpperCase() || 'ALL';
      this.filterDefinitions(type);
    });
  }

  public filterDefinitions(type: string) {
    this.filteredTemplates = type === 'ALL'
      ? this.templates
      : this.templates.filter(def => def.type === type);
  }

}
