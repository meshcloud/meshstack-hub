import { Injectable } from '@angular/core';
import { ParamMap } from '@angular/router';
import { Observable,combineLatest, map, of } from 'rxjs';

import { PlatformService } from 'app/shared/platform';
import { TemplateService } from 'app/shared/template';

import { BreadcrumbItem } from './breadcrumb';

@Injectable({
  providedIn: 'root',
})
export class BreadCrumbService {
  constructor(
    private templateService: TemplateService,
    private platformService: PlatformService
  ) {}


  public getBreadcrumbs(paramMap: ParamMap): Observable<BreadcrumbItem[]> {
    const platformType = paramMap.get('type');
    const definitionId = paramMap.get('id');

    return combineLatest({
      platformName: platformType ? this.getPlatformName(platformType) : of(null),
      templateName: definitionId ? this.getDefinitionName(definitionId) : of(null)
    })
      .pipe(
        map(({ platformName, templateName }) =>
          this.buildBreadcrumbs(templateName, platformName, platformType)
        )
      );
  }


  private getDefinitionName(id: string): Observable<string> {
    return this.templateService.getTemplateById(id)
      .pipe(map(template => template.name));
  }

  private getPlatformName(type: string): Observable<string> {
    return this.platformService.getPlatformData(type)
      .pipe(map(platform => platform.name));
  }

  private buildBreadcrumbs(
    templateName: string | null,
    platformName: string | null,
    type: string | null
  ): BreadcrumbItem[] {
    const breadcrumbs: BreadcrumbItem[] = [{ label: 'Home', routePath: '/' }];

    if (platformName) {
      breadcrumbs.push({ label: platformName, routePath: `/platforms/${type}` });
    }

    if (templateName) {
      breadcrumbs.push({ label: templateName, routePath: '' });
    }

    if (breadcrumbs.length > 0) {
      breadcrumbs[breadcrumbs.length - 1].routePath = '';
    }

    return breadcrumbs;
  }
}