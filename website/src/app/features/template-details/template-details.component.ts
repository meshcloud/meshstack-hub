import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { Observable, Subscription, forkJoin, map } from 'rxjs';

import { PlatformType } from 'app/core';
import { PlatformLogoService } from 'app/shared/platform-logo';
import { TemplateService } from 'app/shared/template';

interface TemplateDetailsVm {
  imageUrl: string | null;
  name: string;
  platformType: PlatformType;
  description: string;
  howToUse: string;
  source: string;
}

@Component({
  selector: 'mst-template-details',
  imports: [CommonModule],
  templateUrl: './template-details.component.html',
  styleUrl: './template-details.component.scss',
  standalone: true

})
export class TemplateDetailsComponent implements OnInit, OnDestroy {
  public template$!: Observable<TemplateDetailsVm>;

  public copyLabel = 'Copy';

  private routeSubscription!: Subscription;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private platformLogoService: PlatformLogoService
  ) { }


  public ngOnInit(): void {
    this.routeSubscription = this.route.paramMap.subscribe(params => {
      const id = params.get('id');

      if (!id) {
        throw new Error('Template ID is required');
      }

      const logos$ = this.platformLogoService.getLogoUrls();
      this.template$ = forkJoin({
        template: this.templateService.getTemplateById(id),
        logos: logos$
      })
        .pipe(
          map(({ template, logos }) => ({
            ...template,
            imageUrl: logos[template.platformType] ?? null,
            source: template.githubUrls.https,
            howToUse: template.howToUse
          }))
        );
    });
  }

  public ngOnDestroy(): void {
    this.routeSubscription.unsubscribe();
  }

  public copyToClipboard(value: string) {
    navigator.clipboard.writeText(value)
      .then(() => {
        this.copyLabel = 'Copied';
        setTimeout(() => {
          this.copyLabel = 'Copy';
        }, 1000);
      })
      .catch(e => console.log(e));
  }

}
