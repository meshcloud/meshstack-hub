import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { Observable, switchMap, of, map } from 'rxjs';

import { BreadcrumbComponent } from 'app/shared/breadcrumb';
import { BreadCrumbService } from 'app/shared/breadcrumb/bread-crumb.service';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { CardComponent } from 'app/shared/card';
import { PlatformService, Platform } from 'app/shared/platform';
import { extractLogoColor } from 'app/shared/util/logo-color.util';
import { HighlightDirective } from 'app/shared/directives';

const DEFAULT_HEADER_BG_COLOR = 'rgba(203,213,225,0.3)';

@Component({
  selector: 'mst-platform-integration',
  imports: [CommonModule, CardComponent, BreadcrumbComponent, RouterLink, HighlightDirective],
  templateUrl: './platform-integration.component.html',
  styleUrl: './platform-integration.component.scss',
  standalone: true
})
export class PlatformIntegrationComponent implements OnInit {
  public platform$!: Observable<Platform>;
  public breadcrumbs$!: Observable<BreadcrumbItem[]>;
  public copiedTerraform = false;
  public headerBgColor$!: Observable<string>;

  constructor(
    private route: ActivatedRoute,
    private platformService: PlatformService,
    private breadcrumbService: BreadCrumbService
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
              return platform;
            })
          );
      })
    );

    this.breadcrumbs$ = this.route.paramMap.pipe(
      switchMap(x => this.breadcrumbService.getBreadcrumbs(x))
    );

    // Reactive header background color
    this.headerBgColor$ = this.platform$.pipe(
      switchMap(platform =>
        platform && platform.logo
          ? extractLogoColor(platform.logo).pipe(
              map(color => {
                return color || DEFAULT_HEADER_BG_COLOR;
              })
            )
          : of(DEFAULT_HEADER_BG_COLOR)
      )
    );
  }

  public copyTerraform(content: string): void {
    navigator.clipboard.writeText(content).then(() => {
      this.copiedTerraform = true;
      setTimeout(() => this.copiedTerraform = false, 2000);
    });
  }
}
