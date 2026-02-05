import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Observable, Subscription, map, switchMap, of } from 'rxjs';

import { BreadcrumbComponent } from 'app/shared/breadcrumb';
import { BreadCrumbService } from 'app/shared/breadcrumb/bread-crumb.service';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { DefinitionCard } from 'app/shared/definition-card/definition-card';
import { DefinitionCardComponent } from 'app/shared/definition-card/definition-card.component';
import { Platform, PlatformService } from 'app/shared/platform';
import { TemplateService } from 'app/shared/template';
import { extractLogoColor } from 'app/shared/util/logo-color.util';

interface PlatformVM {
  logo: string | null;
  title: string;
  description: string; // Added description property
}

@Component({
  selector: 'mst-platform-view',
  imports: [CommonModule, DefinitionCardComponent, BreadcrumbComponent, RouterLink],
  templateUrl: './platform-view.component.html',
  styleUrl: './platform-view.component.scss',
  standalone: true
})
export class PlatformViewComponent implements OnInit, OnDestroy {
  public platform$!: Observable<PlatformVM>;

  public breadcrumbs$!: Observable<BreadcrumbItem[]>;

  public templates$!: Observable<DefinitionCard[]>;

  public hasIntegration: boolean = false;

  public currentPlatformType: string = '';

  private paramSubscription!: Subscription;

  public logoBackgroundColor$!: Observable<string>;

  constructor(
    private router: Router,
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private platformService: PlatformService,
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
        this.currentPlatformType = type;
        this.platform$ = this.platformService.getAllPlatforms()
          .pipe(
            map(platforms => {
              const templateObs$ = this.templateService.filterTemplatesByPlatformType(type);
              this.templates$ = this.getTemplatesWithLogos(templateObs$, platforms, type);

              const platform = platforms.find(p => p.platformType === type);

              if (!platform) {
                throw new Error(`Platform ${type} not found`);
              }

              this.hasIntegration = !!platform.terraformSnippet;
              return {
                logo: platform.logo,
                title: platform.name,
                description: platform.description
              };
            })
        );
        // Compose logoBackgroundColor$ reactively from platform$
        const DEFAULT_LOGO_BG_COLOR = 'rgba(203,213,225,0.3)';
        this.logoBackgroundColor$ = this.platform$.pipe(
          switchMap(platform =>
            platform.logo
              ? extractLogoColor(platform.logo).pipe(
                  map(color => color || DEFAULT_LOGO_BG_COLOR)
                )
              : of(DEFAULT_LOGO_BG_COLOR)
          )
        );


      } else {
        this.router.navigate(['/all']);
      }
    });
  }

  private getTemplatesWithLogos(
    templateObs$: Observable<any>,
    platforms: Platform[],
    type: string
  ): Observable<DefinitionCard[]> {
    return templateObs$
      .pipe(
        map(templates =>
          templates.map(item => ({
            cardLogo: item.logo,
            title: item.name,
            description: item.description,
            routePath: `/platforms/${type}/definitions/${item.id}`,
            supportedPlatforms: item.supportedPlatforms.map(platform => ({
              platformType: platform,
              imageUrl: platforms.find(p => p.platformType === item.platformType)?.logo ?? null
            }))
          }))
        )
      );
  }
}
