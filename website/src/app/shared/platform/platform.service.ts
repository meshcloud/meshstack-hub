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
        return { name: 'Azure', logo: logoUrl };
      case 'aws':
        return { name: 'Amazon Web Services', logo: logoUrl };
      case 'gcp':
        return { name: 'Google Cloud', logo: logoUrl };
      case 'github':
        return { name: 'GitHub', logo: logoUrl };
      case 'aks':
        return { name: 'Azure Kubernetes Service', logo: logoUrl };
      case 'kubernetes':
        return { name: 'Kubernetes', logo: logoUrl };
      case 'ionos':
        return { name: 'IONOS', logo: logoUrl };
      case 'stackit':
        return { name: 'STACKIT', logo: logoUrl };
      case 'datadog':
        return { name: 'DataDog', logo: logoUrl };
      case 'cloudfoundry':
        return { name: 'Cloud Foundry', logo: logoUrl };
      case 'ovh':
        return { name: 'OVHcloud', logo: logoUrl };
      case 'sapbtp':
        return { name: 'SAP Business Technology Platform', logo: logoUrl };
      case 'azuredevops':
        return { name: 'Azure DevOps', logo: logoUrl };
      case 'openstack':
        return { name: 'OpenStack', logo: logoUrl };
      case 'openshift':
        return { name: 'OpenShift', logo: logoUrl };
      case 'oci':
        return { name: 'Oracle Cloud Infrastructure', logo: logoUrl };
      case 'tencentcloud':
        return { name: 'Tencent Cloud', logo: logoUrl };
      default:
        return { name: key, logo: logoUrl };
    }
  }

}
