import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { Observable, map, of, switchMap } from 'rxjs';

import { BreadcrumbComponent } from 'app/shared/breadcrumb';
import { BreadCrumbService } from 'app/shared/breadcrumb/bread-crumb.service';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { CardComponent } from 'app/shared/card';
import { HighlightDirective } from 'app/shared/directives';
import { Platform, PlatformService } from 'app/shared/platform';
import { extractLogoColor } from 'app/shared/util/logo-color.util';
import { buildHubModuleCodeSnippet } from 'app/shared/util/module-source.util';
import { SeoService } from 'app/core';

const DEFAULT_HEADER_BG_COLOR = 'rgba(203,213,225,0.3)';

interface PlatformIntegrationVm extends Platform {
  moduleCodeSnippet: string | null;
}

@Component({
  selector: 'mst-platform-integration',
  imports: [CommonModule, CardComponent, BreadcrumbComponent, RouterLink, HighlightDirective],
  templateUrl: './platform-integration.component.html',
  styleUrl: './platform-integration.component.scss',
  standalone: true
})
export class PlatformIntegrationComponent implements OnInit {
  public platform$!: Observable<PlatformIntegrationVm>;

  public breadcrumbs$!: Observable<BreadcrumbItem[]>;

  public copiedTerraform = false;

  public copiedModuleCode = false;

  public headerBgColor$!: Observable<string>;

  constructor(
    private route: ActivatedRoute,
    private platformService: PlatformService,
    private breadcrumbService: BreadCrumbService,
    private seoService: SeoService
  ) { }

  public ngOnInit(): void {
    this.platform$ = this.route.paramMap.pipe(
      switchMap(params => {
        const type = params.get('type');

        if (!type) {
          throw new Error('Platform type not given in URL');
        }

        return this.platformService.getAllPlatforms()
          .pipe(
            map(platforms => {
              const platform = platforms.find(p => p.platformType === type);

              if (!platform) {
                throw new Error('Platform not found');
              }

              return {
                ...platform,
                moduleCodeSnippet: buildHubModuleCodeSnippet(platform.integrationSourceUrl)
              };
            })
          );
      })
    );
    this.platform$.subscribe(platform => {
      this.seoService.set(
        `Integrate ${platform.name} with meshStack`,
        `Step-by-step guide to integrating ${platform.name} into your meshStack instance using Terraform.`
      );
    });

    this.breadcrumbs$ = this.route.paramMap.pipe(
      switchMap(x => this.breadcrumbService.getBreadcrumbs(x))
    );

    // Reactive header background color
    this.headerBgColor$ = this.platform$.pipe(
      switchMap(platform =>
        platform && platform.logo
          ? extractLogoColor(platform.logo)
            .pipe(
              map(color => color || DEFAULT_HEADER_BG_COLOR)
            )
          : of(DEFAULT_HEADER_BG_COLOR)
      )
    );
  }

  public copyTerraform(content: string): void {
    navigator.clipboard.writeText(content)
      .then(() => {
        this.copiedTerraform = true;
        setTimeout(() => this.copiedTerraform = false, 2000);
        const plausible = (window as Window & { plausible?: (eventName: string) => void }).plausible;
        plausible?.('Copy Platform Terraform');
      });
  }

  public copyModuleCode(moduleCodeSnippet: string | null): void {
    if (!moduleCodeSnippet) {
      return;
    }

    navigator.clipboard.writeText(moduleCodeSnippet)
      .then(() => {
        this.copiedModuleCode = true;
        setTimeout(() => {
          this.copiedModuleCode = false;
        }, 2000);
      });
  }

}
