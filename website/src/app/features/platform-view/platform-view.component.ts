import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { Observable, Subscription, forkJoin, map, switchMap } from 'rxjs';

import { PlatformType } from 'app/core';
import { BreadcrumbComponent } from 'app/shared/breadcrumb';
import { BreadCrumbService } from 'app/shared/breadcrumb/bread-crumb.service';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { CardComponent } from 'app/shared/card';
import { DefinitionCard } from 'app/shared/definition-card/definition-card';
import { DefinitionCardComponent } from 'app/shared/definition-card/definition-card.component';
import { LogoCircleComponent } from 'app/shared/logo-circle';
import { PlatformData, PlatformService } from 'app/shared/platform';
import { TemplateService } from 'app/shared/template';

interface PlatformVM {
  logo: string | null;
  title: string;
}

@Component({
  selector: 'mst-platform-view',
  imports: [CommonModule, DefinitionCardComponent, CardComponent, LogoCircleComponent, BreadcrumbComponent],
  templateUrl: './platform-view.component.html',
  styleUrl: './platform-view.component.scss',
  standalone: true
})
export class PlatformViewComponent implements OnInit, OnDestroy {
  public platform$!: Observable<PlatformVM>;

  public breadcrumbs$!: Observable<BreadcrumbItem[]>;

  public templates$!: Observable<DefinitionCard[]>;

  private paramSubscription!: Subscription;

  private platformData$!: Observable<PlatformData>;

  constructor(
    private router: Router,
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private platformLogoService: PlatformService,
    private breadcrumbService: BreadCrumbService
  ) { }

  public ngOnInit(): void {
    this.subscribeToRouteParams();
    this.breadcrumbs$ = this.route.paramMap.pipe(switchMap(x => this.breadcrumbService.getBreadcrumbs(x)));

  }

  public ngOnDestroy(): void {
    this.paramSubscription.unsubscribe();
  }

  private subscribeToRouteParams(): void {
    this.paramSubscription = this.route.paramMap.subscribe(params => {
      const type = params.get('type');

      if (type) {
        const templateObs$ = this.templateService.filterTemplatesByPlatformType(type as PlatformType);
        this.platformData$ = this.platformLogoService.getAllPlatformData();
        this.platform$ = this.platformData$.pipe(
          map(platformData => ({
            logo: platformData[type]?.logo ?? null,
            title: platformData[type]?.name ?? ''
          }),

          )
        );
        this.templates$ = this.getTemplatesWithLogos(templateObs$, type);

      } else {
        this.router.navigate(['/all']);
      }
    });
  }

  private getTemplatesWithLogos(templateObs$: Observable<any>, type: string): Observable<DefinitionCard[]> {
    return forkJoin({
      templates: templateObs$,
      platforms: this.platformData$
    })
      .pipe(
        map(({ templates, platforms }) =>
          templates.map(item => ({
            cardLogo: item.logo,
            title: item.name,
            description: item.description,
            routePath: `/platforms/${type}/definitions/${item.id}`,
            supportedPlatforms: item.supportedPlatforms.map(platform => ({
              platformType: platform,
              imageUrl: platforms[item.platformType].logo ?? null
            }))
          }))
        )
      );
  }
}
