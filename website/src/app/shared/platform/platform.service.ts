import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable, map, shareReplay, take } from 'rxjs';

import { Platform, PlatformData, PlatformLogoData } from './platform-data';

@Injectable({
  providedIn: 'root'
})
export class PlatformService {
  private logoDataCache$: Observable<PlatformData> | null = null;

  constructor(private http: HttpClient) { }

  public getAllPlatformData(): Observable<PlatformData> {
    if (!this.logoDataCache$) {
      this.logoDataCache$ = this.http.get<PlatformLogoData>('/assets/platform-logos.json')
        .pipe(
          take(1),
          shareReplay(1),
          map((data: PlatformLogoData) =>
            Object.entries(data)
              .reduce((acc, [key, logoUrl]) => {
                acc[key] = this.getPlatform(key, logoUrl);

                return acc;
              }, {} as PlatformData)
          )
        );
    }

    return this.logoDataCache$;
  }

  public getPlatformData(platform: string): Observable<Platform> {
    return this.getAllPlatformData()
      .pipe(
        map((data: PlatformData) => {
          const platformData = data[platform];

          if (!platformData) {
            throw new Error(`Platform ${platform} not found`);
          }

          return platformData;
        }
        )
      );
  }

  private getPlatform(key: string, logoUrl: string): Platform {
    switch (key) {
      case 'azure':
        return { name: 'Azure', logo: logoUrl, description: 'Cloud services by Microsoft', category: 'hyperscaler' };
      case 'aws':
        return { name: 'Amazon Web Services', logo: logoUrl, description: 'Amazon\'s scalable cloud platform', category: 'hyperscaler' };
      case 'gcp':
        return { name: 'Google Cloud', logo: logoUrl, description: 'Cloud solutions by Google', category: 'hyperscaler' };
      case 'github':
        return { name: 'GitHub', logo: logoUrl, description: 'Version control platform', category: 'devops' };
      case 'aks':
        return { name: 'Azure Kubernetes Service', logo: logoUrl, description: 'Managed Kubernetes service on Azure', category: 'hyperscaler' };
      case 'kubernetes':
        return { name: 'Kubernetes', logo: logoUrl, description: 'Container orchestration platform', category: 'devops' };
      case 'ionos':
        return { name: 'IONOS', logo: logoUrl, description: 'European cloud and hosting provider', category: 'european' };
      case 'stackit':
        return { name: 'STACKIT', logo: logoUrl, description: 'Cloud platform by Schwarz IT', category: 'european' };
      case 'datadog':
        return { name: 'DataDog', logo: logoUrl, description: 'Monitoring and analytics platform', category: 'devops' };
      case 'cloudfoundry':
        return { name: 'Cloud Foundry', logo: logoUrl, description: 'Open-source cloud application platform', category: 'private-cloud' };
      case 'ovh':
        return { name: 'OVHcloud', logo: logoUrl, description: 'European cloud service provider', category: 'european' };
      case 'sapbtp':
        return { name: 'SAP Business Technology Platform', logo: logoUrl, description: 'SAP\'s platform-as-a-service solution', category: 'european' };
      case 'azuredevops':
        return { name: 'Azure DevOps', logo: logoUrl, description: 'DevOps tools and services by Microsoft', category: 'devops' };
      case 'openstack':
        return { name: 'OpenStack', logo: logoUrl, description: 'Open-source cloud infrastructure platform', category: 'private-cloud' };
      case 'openshift':
        return { name: 'OpenShift', logo: logoUrl };
      case 'oci':
        return { name: 'Oracle Cloud Infrastructure', logo: logoUrl };
      case 'tencentcloud':
        return { name: 'Tencent Cloud', logo: logoUrl, description: 'Cloud services by Tencent', category: 'china' };
      default:
        return { name: key, logo: logoUrl };
    }
  }

}
