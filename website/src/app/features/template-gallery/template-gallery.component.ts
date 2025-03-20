import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { PlatformType, Template } from 'app/core';
import { CardComponent } from 'app/shared/card';
import { PlatformLogoService } from 'app/shared/platform-logo';
import { TemplateService } from 'app/shared/template';
import { Observable, Subscription, forkJoin, map, take } from 'rxjs';

interface TemplateVm extends Template {
  imageUrl: string | null;
}

@Component({
  selector: 'app-template-gallery',
  imports: [CommonModule, CardComponent],
  templateUrl: './template-gallery.component.html',
  styleUrl: './template-gallery.component.scss',
  standalone: true
})
export class TemplateGalleryComponent implements OnInit, OnDestroy {

  public templates$!: Observable<TemplateVm[]>;

  private routeSubscription!: Subscription;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private platformLogoService: PlatformLogoService
  ) { }


  public ngOnInit(): void {
    this.routeSubscription = this.route.paramMap.subscribe(params => {
      const type = params.get('type') as PlatformType ?? 'all';
      const logos$ = this.platformLogoService.getLogoUrls();
      this.templates$ = forkJoin({
        templates: this.templateService.filterTemplatesByPlatformType(type),
        logos: logos$
      })
        .pipe(
          map(({ templates, logos }) =>
            templates.map(item => ({
              ...item,
              imageUrl: logos[item.platformType] ?? null
            }))
          )
        );
    });
  }

  public ngOnDestroy(): void {
    this.routeSubscription.unsubscribe();
  }

}
